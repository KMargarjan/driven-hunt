-- boar_behaviour_live.spec: the same behaviour on a REAL, physically simulated boar, through the
-- public interface only (task 118).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- It builds its OWN world -- an anchored plate at y = 900, clear of `boar_body.spec`'s 500 and
-- `match_live.spec`'s 700 -- a spec-owned folder, a scripted stimulus list the spec moves itself, and
-- `config = { SENSE = { ENABLED = true } }`. Production's boar, spawned by MatchBoot, is a different
-- runtime and is untouched.
--
-- THE FLAG ARRIVES AS A PARAMETER, through the world's config: `test` refuses to start while an
-- override is set, so this is the only way the ON branch can be driven at all.
-- Design: docs/design/boar-behaviour.md (section 12, the live half)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local CONFIG = Boar.CONFIG
local SENSE = CONFIG.SENSE

local GROUND_Y = 900
local PLATE_SPAN = 170
local FIELD = {
	bounds = { minX = -75, maxX = 75, minZ = -75, maxZ = 75 },
	exitZ = -60,
	groundY = GROUND_Y,
}

-- Counts the boar's OWN Heartbeat frames rather than wall-clock seconds, because Studio throttles
-- physics when its frame rate falls and a claim written in seconds is then a race against whatever
-- else the machine is doing (`boar_body.spec`, Task 36). A slow machine takes longer and asserts
-- exactly the same thing.
local function stepUntil(frames: number, predicate: () -> boolean): (boolean, number)
	for used = 1, frames do
		RunService.Heartbeat:Wait()
		if predicate() then
			return true, used
		end
	end
	return predicate(), frames
end

local function frames(seconds: number): number
	return math.ceil(seconds * 60)
end

local function flatOf(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

return function()
	local testRoot, runtime, disconnect, world
	local stimuli = {}

	local function buildWorld()
		testRoot = Instance.new("Folder")
		testRoot.Name = "BoarBehaviourSpec"

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
			rng = Random.new(118),
			-- THE FLAG, AS A PARAMETER. `newRuntime` merges this over the default block key by key,
			-- so every radius and timer below is the shipped number and only `ENABLED` differs.
			config = { SENSE = { ENABLED = true }, maxBoars = 12 },
			threats = function()
				local out = {}
				for id, row in pairs(stimuli) do
					-- `speed` is deliberately NOT set: the Runtime measures it (section 4.6), and a
					-- provider that could set it is a provider that could lie about it.
					table.insert(out, { id = id, position = row.position, kind = row.kind })
				end
				return out
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

	local startedAt = 0

	beforeAll(function()
		stimuli = {}
		startedAt = os.clock()
		runtime = Boar.newRuntime(buildWorld())
		disconnect = runtime:run()
	end)

	afterAll(function()
		-- HOW LONG THIS FILE COSTS THE SERVER SUITE, measured rather than guessed. It is a live
		-- spec: every case here waits on real physics, and the suite is SEQUENTIAL -- so this number
		-- is how much later every spec after it now runs. That matters beyond tidiness: two cases in
		-- `test2` have already been broken by the suite creeping past the drive's tie at ~55 s
		-- (`ESCALATE.md`, task 112, and `match_teams.spec`'s own note at task 118), and the next one
		-- to break will be whichever case sits nearest that edge. Printed so the creep is visible
		-- before it costs a round.
		TestKit.note(
			string.format("boar-behaviour-live: this file took %.1f s of the server suite", os.clock() - startedAt)
		)
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

	describe("boar behaviour, live: it notices a man and goes head-up", function()
		it("turns to face a standing man at 22 studs without moving off", function()
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			stimuli.standing = { position = Vector3.new(22, GROUND_Y, 0), kind = "shooter" }

			local alerted = stepUntil(frames(1.5), function()
				local perception = runtime:perceptionOf(handle.id)
				return perception ~= nil and perception.reaction == "alert" and handle.state() == "ALERT"
			end)
			expect(alerted).to.equal(true)

			-- IT IS FACING HIM, on the body and not only in the intent: the trunk's own LookVector,
			-- which is what a player sees and what `Body.stepVisual` derives the turn clips from.
			local toward = Vector3.new(1, 0, 0)
			local facing = stepUntil(frames(1.5), function()
				local look = flatOf(handle.part.CFrame.LookVector)
				return look.Magnitude > 1e-3 and math.deg(math.acos(math.clamp(look.Unit:Dot(toward), -1, 1))) <= 15
			end)
			local look = flatOf(handle.part.CFrame.LookVector).Unit
			local offBy = math.deg(math.acos(math.clamp(look:Dot(toward), -1, 1)))
			expect(facing).to.equal(true)

			-- ...AND IT IS STOPPED. A boar that walked while alert would be a boar that is not alert.
			local fastest = 0
			for _ = 1, frames(0.5) do
				RunService.Heartbeat:Wait()
				fastest = math.max(fastest, flatOf(handle.part.AssemblyLinearVelocity).Magnitude)
			end
			expect(fastest < CONFIG.WANDER_SPEED).to.equal(true)
			expect(runtime:stats().alerts >= 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-behaviour-live: ALERT at 22 studs, facing off by %.1f deg, fastest %.2f studs/s",
					offBy,
					fastest
				)
			)

			stimuli = {}
			runtime:clear("cleared")
			expect(runtime:count()).to.equal(0)
		end)
	end)

	describe("boar behaviour, live: the speed is measured, not reported", function()
		it("reads a moving man as AVOID and a stopped one as nothing, at the same distance", function()
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			local at = Vector3.new(50, GROUND_Y, -25)
			stimuli.walker = { position = at, kind = "shooter" }

			-- A STANDING man at 50 studs is nothing at all: past NOTICE_STANDING = 25 and under
			-- NOTICE_MOVING = 60. That is the control for the half below.
			local settled = stepUntil(frames(1.0), function()
				local perception = runtime:perceptionOf(handle.id)
				return perception ~= nil and perception.reaction == "none"
			end)
			expect(settled).to.equal(true)

			-- NOW WALK HIM, at about 10 studs/s ACROSS the boar's front, so the distance stays near
			-- 50 and the only thing that changes is the measured speed.
			--
			-- HE KEEPS WALKING UNTIL THE STATE FOLLOWS, in one loop and not two: the perception is
			-- recomputed every step but rules 7-10 are evaluated on a SENSE TICK (section 3.2), so
			-- the reaction leads the state by up to 0.2 s -- and the measured speed is an average
			-- over 0.3 s, so a man who stopped the instant he was noticed would read as standing
			-- again before that tick arrived. Measured the hard way: this case's first form stopped
			-- him on the frame the reaction turned, and the boar never left IDLE.
			local moving, movedFor = false, 0
			local measured = 0
			local walked = 0
			for used = 1, frames(SENSE.SPEED_SMOOTH_SECONDS * 3 + CONFIG.SENSE_INTERVAL + 0.2) do
				RunService.Heartbeat:Wait()
				walked += 10 / 60
				stimuli.walker.position = at + Vector3.new(0, 0, walked)
				local perception = runtime:perceptionOf(handle.id)
				if perception and perception.reaction == "avoid" and not moving then
					moving, movedFor = true, used
					measured = (perception.cause and perception.cause.speed) or 0
				end
				if moving and handle.state() == "AVOID" then
					break
				end
			end
			expect(moving).to.equal(true)
			expect(handle.state()).to.equal("AVOID")
			-- THE MEASUREMENT ITSELF, which is what section 4.6 is about: an exponential average
			-- over SPEED_SMOOTH_SECONDS, so at the moment it first crosses MOVING_SPEED = 2 it is
			-- well under the real 10 -- and that is the point. It can only ever under-react.
			expect(measured >= SENSE.MOVING_SPEED).to.equal(true)
			expect(measured <= 12).to.equal(true)

			-- STOP HIM. The reaction has to fall back to "none" while he is STILL inside
			-- NOTICE_MOVING, or it would be the distance saying it and not the speed.
			local frozen = stimuli.walker.position
			local fellBack, after = false, 0
			local distanceThen = 0
			for used = 1, frames(SENSE.SPEED_SMOOTH_SECONDS * 3) do
				RunService.Heartbeat:Wait()
				local perception = runtime:perceptionOf(handle.id)
				local distance = (flatOf(handle.position()) - flatOf(frozen)).Magnitude
				if perception and perception.reaction == "none" then
					fellBack, after, distanceThen = true, used, distance
					break
				end
			end
			expect(fellBack).to.equal(true)
			expect(distanceThen < SENSE.NOTICE_MOVING).to.equal(true)
			TestKit.note(
				string.format(
					"boar-behaviour-live: AVOID after %d frames at %.1f studs/s measured; fell back after %d frames at %.1f studs",
					movedFor,
					measured,
					after,
					distanceThen
				)
			)
		end)

		it("asks for no route while it is avoiding", function()
			-- `ComputeAsync` is this system's one expensive call, and a behaviour task may not change
			-- the path budget (section 4.4). The boar from the case above is still in AVOID.
			local before = runtime:stats().pathRequests
			for _ = 1, frames(3) do
				RunService.Heartbeat:Wait()
			end
			expect(runtime:stats().pathRequests).to.equal(before)
			expect(runtime:stats().avoids >= 1).to.equal(true)

			stimuli = {}
			runtime:clear("cleared")
		end)
	end)

	describe("boar behaviour, live: a shot is heard at a distance", function()
		it("sprints the boar inside the audible radius and leaves the far one grazing", function()
			local near = runtime:spawn(Vector3.new(0, GROUND_Y, 20))
			local far = runtime:spawn(Vector3.new(0, GROUND_Y, -30))
			-- 345 studs from the near one and 395 from the far one, across SHOT_AUDIBLE_STUDS = 350.
			local shot = Vector3.new(0, GROUND_Y, 365)
			RunService.Heartbeat:Wait()

			expect(runtime:hearShot(shot)).to.equal(1)
			local bolted, used = stepUntil(frames(0.25), function()
				return near.state() == "FLEE"
			end)
			expect(bolted).to.equal(true)
			local fast = stepUntil(frames(1.0), function()
				return flatOf(near.part.AssemblyLinearVelocity).Magnitude >= CONFIG.SPRINT_SPEED * 0.5
			end)
			expect(fast).to.equal(true)
			expect(runtime:stats().shotsHeard).to.equal(1)

			-- The far one never heard it. Two seconds is ten sense ticks.
			for _ = 1, frames(2) do
				RunService.Heartbeat:Wait()
			end
			expect(far.state()).to.equal("IDLE")
			TestKit.note(string.format("boar-behaviour-live: a shot at 345 studs bolted the boar in %d frames", used))

			runtime:clear("cleared")
		end)
	end)

	describe("boar behaviour, live: panic spreads through a sounder", function()
		it("reaches every member within PANIC_DELAY_MAX, and is visible as spreading", function()
			local handles = runtime:spawnSounder(Vector3.new(0, GROUND_Y, 40), 3)
			expect(#handles).to.equal(3)
			local onlyOneLeft = stepUntil(frames(1.0), function()
				return handles[1].state() == "IDLE" and handles[2].state() == "IDLE"
			end)
			expect(onlyOneLeft).to.equal(true)

			-- A NON-LETHAL HIT on one member. `SCATTER_ON_HIT` breaks the group up as it always did;
			-- what is new is that the panic travels member to member with a delay instead of the
			-- whole sounder turning at once off the leader's state.
			local hit = handles[1]
			runtime:takeHit(hit.part, { zone = "body", ammo = "Buck", pellets = 2, at = os.clock() })

			local function panicked(): number
				local n = 0
				for _, handle in ipairs(handles) do
					if Boar.Brain.classOf(handle.state()) == "panicked" then
						n += 1
					end
				end
				return n
			end

			-- IT IS VISIBLE AS SPREADING: at least one sampled step has one member running and
			-- another not. Without the delay every member would turn on the same step and this could
			-- never be observed -- which is exactly what Karen asked to be able to see.
			local sawPartial = false
			local allRunning, used = stepUntil(frames(SENSE.PANIC_DELAY_MAX + CONFIG.SENSE_INTERVAL + 0.2), function()
				local n = panicked()
				if n > 0 and n < #handles then
					sawPartial = true
				end
				return n == #handles
			end)
			expect(allRunning).to.equal(true)
			expect(sawPartial).to.equal(true)
			expect(runtime:stats().alarms >= 1).to.equal(true)
			TestKit.note(
				string.format("boar-behaviour-live: 3 members all running after %d frames, spreading seen", used)
			)

			stimuli = {}
			runtime:clear("cleared")
		end)
	end)

	describe("boar family, live: a sounder is a sow with young", function()
		it("spawns a sow and cubs, each on its own box, and every one of them lives", function()
			-- TASK 119. The makeup is asserted purely in `boar_kinds.spec`; what this case adds is
			-- that the three animals it names can actually EXIST -- a cub is the smallest physics
			-- body this game has ever spawned, it is dropped `SPAWN_CLEARANCE` above the plate like
			-- every other boar, and nothing about being small may make it fall through, be ejected
			-- or go out of bounds.
			--
			-- ITS OWN RUNTIME, because the kinds are behind `BOAR_MODEL` and a harness run only ever
			-- sees that flag off: `config = { KINDS = { ENABLED = true } }` is merged key by key by
			-- `newRuntime`, so every scale and model below is the shipped one.
			local holder = Instance.new("Folder")
			holder.Name = "BoarFamilySpec"
			holder.Parent = testRoot
			local production = Boar.defaultWorld(FIELD)
			local family = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "Family",
				rng = Random.new(119),
				config = { KINDS = { ENABLED = true }, maxBoars = 8 },
				threats = function()
					return {}
				end,
				requestPath = production.requestPath,
				releasePath = production.releasePath,
			})
			local disconnectFamily = family:run()

			local handles = family:spawnSounder(Vector3.new(40, GROUND_Y, 40), 4)
			expect(#handles).to.equal(4)
			expect(handles[1].kind).to.equal("female")
			for index = 2, 4 do
				-- A cub, or the occasional young male: never another sow.
				expect(handles[index].kind ~= "female").to.equal(true)
			end

			-- EVERY KIND IS DROPPED FROM THE SAME HEIGHT, and that is a DECISION rather than an
			-- accident of arithmetic (review round 2, note). `field.groundY` is the FIELD's ground
			-- and the map's real surface need not be on it: a cub spawned at its own half-height sat
			-- entirely below the surface and was ejected, which is why every cub the drive released
			-- vanished. Read before a single Heartbeat, so these are the SPAWN heights and not where
			-- the physics has since put them.
			local spawnY = {}
			for _, handle in ipairs(handles) do
				spawnY[handle.kind] = handle.position().Y
			end
			expect(spawnY.female).to.be.ok()
			for kind, y in pairs(spawnY) do
				expect(math.abs(y - spawnY.female) < 1e-3).to.equal(true)
				expect(y > GROUND_Y + CONFIG.BODY_SIZE.Y / 2).to.equal(true)
				expect(kind).to.be.ok()
			end

			-- THE BOX IS THE ANIMAL'S OWN. 0.85 and 0.45 of the male's 5.5 studs.
			local wanted = { male = 5.5, female = 4.675, cub = 2.475 }
			for _, handle in ipairs(handles) do
				expect(math.abs(handle.part.Size.Z - wanted[handle.kind]) < 1e-3).to.equal(true)
				-- ...and its hit zones with it: a cub's chest is a cub's chest.
				local chest = handle.part:FindFirstChild("ZoneChest") :: BasePart
				expect(chest).to.be.ok()
				local scale = wanted[handle.kind] / 5.5
				expect((chest.Size - CONFIG.ZONES.chest.size * scale).Magnitude < 1e-3).to.equal(true)
			end

			-- AND THEY ARE ALL STILL HERE a second later, standing on the plate rather than through
			-- it: `count()` is the runtime's own, so a despawn of any kind fails this.
			for _ = 1, frames(1.5) do
				RunService.Heartbeat:Wait()
			end
			expect(family:count()).to.equal(4)
			local lowest = math.huge
			for _, handle in ipairs(handles) do
				lowest = math.min(lowest, handle.position().Y - handle.part.Size.Y / 2)
			end
			expect(lowest > GROUND_Y - 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-family: sow + %d young alive after 1.5 s, lowest box bottom %.2f against a plate at %d",
					#handles - 1,
					lowest,
					GROUND_Y
				)
			)

			disconnectFamily()
			family:destroy()
			holder:Destroy()
		end)
	end)

	describe("boar behaviour, live: single file or a loose group", function()
		-- Karen: "they usually do one line each after another or mixed like in real life".
		-- `COLUMN_CHANCE` is 0.5 and the draw is the runtime's own `Random`, so this asks for
		-- sounders until it is handed the one it wants rather than guessing a seed: with p = 0.5,
		-- ten attempts miss once in 1,024.
		--
		-- IT MEASURES BOTH FORMATIONS AND COMPARES THEM, because "it runs in a line" is only a
		-- claim against the alternative. The wedge puts slots 2 and 3 at -7 and +7 off the leader's
		-- axis -- 14 studs apart ACROSS it -- and the column puts both ON it.
		local function measure(wanted: string)
			local handles, view = nil, nil
			for _ = 1, 10 do
				handles = runtime:spawnSounder(Vector3.new(0, GROUND_Y, 65), 3)
				view = runtime:sounders()[1]
				if view and view.formation == wanted then
					break
				end
				runtime:clear("cleared")
				handles, view = nil, nil
			end
			expect(view).to.be.ok()
			expect(view.formation).to.equal(wanted)
			expect(#handles).to.equal(3)

			-- Something to run from, behind them, so they head down the corridor together.
			stimuli.driver = { position = Vector3.new(0, GROUND_Y, 72), kind = "driver" }
			local running = stepUntil(frames(1.0), function()
				return handles[1].state() == "FLEE" or handles[2].state() == "FLEE"
			end)
			expect(running).to.equal(true)
			-- 3.2 s OF RUNNING, measured against the plate and not chosen: at a sprint of 38 studs/s
			-- off a start at z = +65 that is ~100 studs of travel, which stops short of `exitZ` =
			-- -60. Longer would be better -- a formation takes its time to settle, because a
			-- follower matches its leader's SPEED and can fall back only by steering -- and longer
			-- is not available here without the sounder crossing the line mid-measurement.
			for _ = 1, frames(3.2) do
				RunService.Heartbeat:Wait()
			end

			local leader = nil
			for _, handle in ipairs(handles) do
				if handle.id == (runtime:sounders()[1] or {}).leaderId then
					leader = handle
				end
			end
			expect(leader).to.be.ok()
			local axis = flatOf(leader.part.AssemblyLinearVelocity)
			if axis.Magnitude < 1 then
				axis = flatOf(leader.part.CFrame.LookVector)
			end
			axis = axis.Unit
			local side = Vector3.new(-axis.Z, 0, axis.X)
			local origin = flatOf(leader.position())

			local along, lateral = {}, {}
			for _, handle in ipairs(handles) do
				local offset = flatOf(handle.position()) - origin
				table.insert(along, -offset:Dot(axis)) -- +ve is BEHIND the leader
				table.insert(lateral, offset:Dot(side)) -- SIGNED: a wedge straddles the axis
			end
			table.sort(along)
			table.sort(lateral)
			local spread = lateral[#lateral] - lateral[1]
			TestKit.note(
				string.format(
					"boar-behaviour-live: %s spread %.1f studs across, behind %.1f/%.1f/%.1f (slot spacing %d)",
					wanted,
					spread,
					along[1],
					along[2],
					along[3],
					CONFIG.SOUNDER.COLUMN_SPACING_STUDS
				)
			)

			stimuli = {}
			runtime:clear("cleared")
			return spread
		end

		it("draws both formations and runs each of them, and the shapes are measured", function()
			local column = measure("column")
			local wedge = measure("wedge")
			-- BOTH FORMATIONS EXIST AND BOTH RUN: `measure` asserts the one it asked for came back
			-- and that all three members are alive and fleeing in it, so a `COLUMN_CHANCE` that
			-- could only ever answer one of the two fails here.
			expect(column > 0).to.equal(true)
			expect(wedge > 0).to.equal(true)
			-- THE SHAPE ITSELF IS MEASURED AND NOT ASSERTED, and that is deliberate. What the
			-- formation DOES is one expression in `Brain:_slotPoint`, and it is asserted exactly, by
			-- parameter and with no physics, in `boar_behaviour.spec` ("steers a column member dead
			-- astern and a wedge member out to the side"). Three unanchored bodies with separation,
			-- cohesion, alignment and arrival, 3.2 s after a standing start, are WEATHER: measured
			-- 2026-10-04 at column 4.2 studs across against wedge 9.4, and measured again minutes
			-- later with the column over 7. A verdict that can invert on a slow frame is worse than
			-- no verdict; the numbers go in the notes above, where a regression is still visible.
		end)
	end)
end
