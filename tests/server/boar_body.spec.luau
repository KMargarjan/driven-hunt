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
				-- UPRIGHT AT EVERY SAMPLE OF THE GETAWAY, which is as much of the design's "throughout
				-- a 3 s flee" (boar-ai section 11) as this test observes: the loop stops as soon as the
				-- boar has gained its 20 studs, which at SPRINT_SPEED takes under a second. It used to
				-- be sampled only until the body reached half sprint speed, a handful of frames in, so
				-- a boar that tipped over while running proved nothing (TASKS.md 36a(3)(c)).
				upright = upright and (handle.part.Parent == nil or handle.part.CFrame.UpVector.Y > 0.9)
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
			expect(upright).to.equal(true)
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
	-- ONE REAL SOUNDER OF FIVE, physically simulated, through the public interface only.
	--
	-- Its own plate, its own runtime and its own threat, torn down in afterAll -- exactly as the
	-- block above does. IT SITS AT y = 1500, not the design's 500: the runtime above is still alive
	-- while this block runs (its beforeAll wraps the file), and two herds of boars sharing one
	-- patch of Workspace would be a physics interaction nobody wrote.
	--
	-- Design: docs/design/drive.md ("boar_body.spec.luau -- CHANGED, live: one real sounder of five")
	describe("boar sounder, live", function()
		local SOUNDER_Y = 1500
		-- A BIG field, and that is the point: the block above uses a 120-stud plate because ONE boar
		-- crossing a short line is what it is testing. Here the sounder has to still EXIST after
		-- three seconds of sprinting, a six-second scatter and the four seconds the break rule
		-- takes -- and a boar that crosses `exitZ` has escaped and is despawned. At 1,100 studs it
		-- would take ~28 s of trotting to reach the line, so nothing escapes while this block runs.
		local SOUNDER_SPAN = 1200
		local SOUNDER_FIELD = {
			bounds = { minX = -500, maxX = 500, minZ = -500, maxZ = 500 },
			exitZ = -480,
			groundY = SOUNDER_Y,
		}
		local CENTER = Vector3.new(0, SOUNDER_Y, 25)
		local SETTINGS = CONFIG.SOUNDER

		local root, herd, herdWorld, herdThreat, herdRecords, stop
		-- WHO ASKED. `stats().pathRequests` is a total, and the invariant this block is here to
		-- prove is about WHICH boar asks: one route per sounder, whatever its size. The spec owns
		-- the world, so counting them here is the one honest way to attribute them.
		local pathCalls = {}

		local function spread(handles): number
			local worst = 0
			for i = 1, #handles do
				for j = i + 1, #handles do
					local a, b = handles[i].position(), handles[j].position()
					worst = math.max(worst, (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude)
				end
			end
			return worst
		end

		local function live(handles)
			local out = {}
			for _, handle in ipairs(handles) do
				local state = handle.state()
				if state ~= "DOWN" and state ~= "GONE" and handle.part.Parent then
					table.insert(out, handle)
				end
			end
			return out
		end

		local function handleOf(handles, id: string?)
			for _, handle in ipairs(handles) do
				if handle.id == id then
					return handle
				end
			end
			return nil
		end

		beforeAll(function()
			herdThreat = nil
			herdRecords = {}
			pathCalls = {}

			root = Instance.new("Folder")
			root.Name = "BoarSounderSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(SOUNDER_SPAN, 4, SOUNDER_SPAN)
			plate.Position = Vector3.new(0, SOUNDER_Y - 2, 0)
			plate.Anchored = true
			plate.TopSurface = Enum.SurfaceType.Smooth
			plate.Parent = root
			root.Parent = Workspace

			local production = Boar.defaultWorld(SOUNDER_FIELD)
			herdWorld = {
				field = SOUNDER_FIELD,
				parent = root,
				folderName = "Boars",
				rng = Random.new(5),
				threats = function()
					if not herdThreat then
						return {}
					end
					return { { id = "herd-spec", position = herdThreat } }
				end,
				probe = function(from: Vector3, direction: Vector3, length: number): boolean
					if direction.Magnitude < 1e-6 then
						return false
					end
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = if herdWorld.folder then { herdWorld.folder } else {}
					return Workspace:Raycast(from, direction.Unit * length, params) ~= nil
				end,
				requestPath = function(agentId: string, from: Vector3, to: Vector3, done, onBlocked)
					pathCalls[agentId] = (pathCalls[agentId] or 0) + 1
					return production.requestPath(agentId, from, to, done, onBlocked)
				end,
				releasePath = production.releasePath,
				pathProblems = production.pathProblems,
			}
			herd = Boar.newRuntime(herdWorld)
			herd.Despawned:Connect(function(record)
				table.insert(herdRecords, record)
			end)
			stop = herd:run()
		end)

		afterAll(function()
			if stop then
				stop()
			end
			if herd then
				herd:destroy()
			end
			if root then
				root:Destroy()
			end
		end)

		local group = nil

		it("spawns exactly five, on a ring inside the pad, as one sounder with one leader", function()
			group = herd:spawnSounder(CENTER, 5, 14)
			expect(#group).to.equal(5)
			for _, handle in ipairs(group) do
				local at = handle.position()
				expect((Vector3.new(at.X, 0, at.Z) - Vector3.new(CENTER.X, 0, CENTER.Z)).Magnitude <= 14).to.equal(true)
			end
			-- No two members share a footprint: five on a ring of 10 stand ~11.8 studs apart.
			for i = 1, #group do
				for j = i + 1, #group do
					local a, b = group[i].position(), group[j].position()
					expect((a - b).Magnitude >= CONFIG.BODY_SIZE.X).to.equal(true)
				end
			end
			local sounders = herd:sounders()
			expect(#sounders).to.equal(1)
			expect(#sounders[1].memberIds).to.equal(5)
			expect(sounders[1].leaderId).to.be.ok()
			expect(herd:sounderOf(group[1].id)).to.be.ok()
			expect(herd:stats().soundersSpawned).to.equal(1)
		end)

		it("creates NOTHING when the whole sounder does not fit", function()
			-- capacity() is 8 and five are already standing, so three slots are left.
			expect(herd:capacity() - herd:count()).to.equal(3)
			local refused = herd:spawnSounder(CENTER, 5, 14)
			expect(#refused).to.equal(0)
			expect(herd:count()).to.equal(5)
			expect(#herd:sounders()).to.equal(1)
		end)

		it("a size of one is a lone boar, with no sounder record", function()
			local single = herd:spawnSounder(CENTER + Vector3.new(30, 0, 0), 1, 14)
			expect(#single).to.equal(1)
			expect(herd:sounderOf(single[1].id)).to.equal(nil)
			expect(#herd:sounders()).to.equal(1)
			-- ...and shooting it changes nothing about the sounder standing beside it.
			herd:takeHit(single[1].part, { ammo = "Slug", zone = "head", pellets = 1 })
			expect(herd:stats().scatters).to.equal(0)
			expect(#herd:sounders()).to.equal(1)
		end)

		it("runs as a group when a driver appears: together, moving, and upright", function()
			local before = herd:stats()
			herdThreat = CENTER + Vector3.new(0, 0, 25) -- behind them, pushing toward the exit line
			local fast = 0
			local upright = true
			local together = true
			local leaderId = herd:sounders()[1].leaderId

			-- ~3 seconds of the boars' OWN frames, so a slow machine takes longer and asserts the
			-- same thing (the reason the second waiter exists, above).
			stepUntil(180, function()
				local members = live(group)
				local leader = handleOf(members, leaderId)
				for _, handle in ipairs(members) do
					upright = upright and handle.part.CFrame.UpVector.Y > 0.9
					local velocity = handle.part.AssemblyLinearVelocity
					fast = math.max(fast, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
					if leader then
						local a, b = handle.position(), leader.position()
						together = together
							and (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
								<= SETTINGS.BREAK_STUDS
					end
				end
				return false
			end)

			expect(upright).to.equal(true)
			expect(together).to.equal(true)
			expect(fast >= 0.4 * CONFIG.SPRINT_SPEED).to.equal(true)

			-- ONE ROUTE PER SOUNDER: five members fleeing for three seconds, and only the leader
			-- asks. Per-member pathing lands near 30 (design, "one route per sounder").
			local after = herd:stats()
			local askers, total = {}, 0
			for agentId, count in pairs(pathCalls) do
				table.insert(askers, string.format("%s x%d", agentId, count))
				total += count
			end
			table.sort(askers)
			-- ONLY THE LEADER ASKED. This is the invariant, not the total: five members each asking
			-- could also each be routed through a different gate in a hedge, which splits the
			-- sounder in two. The message carries the evidence, because a bare `false` here would
			-- say nothing about which boar broke it.
			if pathCalls[leaderId] == nil or total ~= pathCalls[leaderId] then
				error(
					string.format(
						"one route per sounder: leader %s, but the askers were %s",
						tostring(leaderId),
						table.concat(askers, ", ")
					),
					0
				)
			end
			-- ...and the leader itself did not run away with it: REPATH_INTERVAL is 0.5 s, and
			-- Path.Blocked can force one more when a herd-mate stands on the route.
			if total > 12 then
				local why = {}
				for reason, count in pairs(herdWorld.pathProblems()) do
					table.insert(why, string.format("%dx %s", count, reason))
				end
				table.sort(why)
				error(
					string.format(
						"the leader asked %d times in 3 s (%d failed, %d blocked%s), over the budget of 12",
						total,
						after.pathFailures - before.pathFailures,
						after.pathBlocked - before.pathBlocked,
						if #why > 0 then "; " .. table.concat(why, ", ") else ""
					),
					0
				)
			end
			expect(after.pathFailures).to.equal(0)
		end)

		it("promotes a new leader and scatters when the leader is shot dead", function()
			local leaderId = herd:sounders()[1].leaderId
			local leader = handleOf(group, leaderId)
			expect(leader).to.be.ok()

			local before = spread(live(group))
			expect(herd:takeHit(leader.part, { ammo = "Slug", zone = "head", pellets = 1 })).to.equal(true)
			expect(herd:stats().scatters >= 1).to.equal(true)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()

			local view = herd:sounders()[1]
			expect(view).to.be.ok()
			expect(view.leaderId).never.to.equal(leaderId)
			expect(herd:stats().leaderPromotions).to.equal(1)
			expect(view.scatterFor > 0).to.equal(true)
			-- A dead member is out of the sounder (LEAVE_ON_MORTAL), carcass and all.
			expect(#view.memberIds).to.equal(4)

			stepUntil(120, function()
				return false
			end)
			expect(spread(live(group)) > before).to.equal(true)
		end)

		it("drops a member that has been too far away for too long", function()
			local view = herd:sounders()[1]
			local strayId = view.memberIds[#view.memberIds]
			local stray = handleOf(group, strayId)
			expect(stray).to.be.ok()
			local before = herd:stats().membersLeft
			local members = #view.memberIds

			-- The WORLD moves it, not the runtime: BREAK_STUDS is 60, so the far corner of the plate
			-- is outside it. (The design drags it with a threat instead; that spends BREAK_SECONDS
			-- of running on top of the four this already waits, for the same assertion.)
			local elapsed = 0
			while elapsed < SETTINGS.BREAK_SECONDS + 1.5 do
				stray.part.CFrame = CFrame.new(Vector3.new(-50, SOUNDER_Y + CONFIG.BODY_SIZE.Y / 2, 50))
				stray.part.AssemblyLinearVelocity = Vector3.zero
				elapsed += RunService.Heartbeat:Wait()
			end

			expect(herd:sounderOf(strayId)).to.equal(nil)
			expect(herd:stats().membersLeft > before).to.equal(true)
			expect(#herd:sounders()[1].memberIds).to.equal(members - 1)
		end)

		it("takes a mortally wounded member out, and the last one dissolves the sounder", function()
			-- One slug to the body is 55 damage against MORTAL = 50: mortal, not lethal -- so the
			-- animal is still alive and still running, and it leaves the sounder because a dying
			-- animal cannot hold formation and the group would otherwise crawl to the line at its
			-- speed (LEAVE_ON_MORTAL).
			local view = herd:sounders()[1]
			local members = #view.memberIds
			expect(members >= 2).to.equal(true)
			local victimId = view.memberIds[#view.memberIds]
			local victim = handleOf(group, victimId)
			expect(victim).to.be.ok()
			expect(herd:takeHit(victim.part, { ammo = "Slug", zone = "body", pellets = 1 })).to.equal(true)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			expect(herd:sounderOf(victimId)).to.equal(nil)

			if members - 1 >= 2 then
				-- Still a group: take the next one out too, down to the last animal.
				local remaining = herd:sounders()[1]
				expect(#remaining.memberIds).to.equal(members - 1)
				local nextId = remaining.memberIds[#remaining.memberIds]
				expect(herd:takeHit(handleOf(group, nextId).part, { ammo = "Slug", zone = "body", pellets = 1 })).to.equal(
					true
				)
				RunService.Heartbeat:Wait()
				RunService.Heartbeat:Wait()
			end

			-- ONE ANIMAL IS NOT A SOUNDER: it dissolves, and the survivor is a lone boar with no
			-- per-step group work left.
			expect(#herd:sounders()).to.equal(0)
			expect(herd:stats().soundersDissolved).to.equal(1)
		end)

		it("clear() removes a whole sounder through the existing despawn path", function()
			herdThreat = nil
			herd:clear("specOver")
			RunService.Heartbeat:Wait()
			expect(herd:count()).to.equal(0)
			expect(#herd:sounders()).to.equal(0)

			local fresh = herd:spawnSounder(CENTER, 5, 14)
			expect(#fresh).to.equal(5)
			expect(#herd:sounders()).to.equal(1)
			local before = #herdRecords
			herd:clear("driveOver")
			RunService.Heartbeat:Wait()
			expect(#herdRecords - before).to.equal(5)
			expect(#herd:sounders()).to.equal(0)
			expect(herd:count()).to.equal(0)
		end)
	end)
end
