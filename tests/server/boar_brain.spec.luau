-- boar_brain.spec: the boar's decisions, with no physics, no Workspace and no waiting.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- The Brain takes its whole world through an Observation, so a threat is just a Vector3 here.
-- Numbers that the design fixes are written out independently of CONFIG where the requirement is
-- absolute (the 0.5 s reaction, the arena rectangle); where the assertion is a relationship, it
-- reads CONFIG, because the relationship is the thing under test.
-- Design: docs/design/boar-ai.md (section 10)
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Brain = Boar.Brain
local CONFIG = Boar.CONFIG

local DT = 1 / 60
-- Vector3 components are float32, so a magnitude near SPRINT_SPEED carries a few parts in 1e-7 of
-- representation error; 1e-6 was tighter than the arithmetic can be and tripped on it (Task 18
-- harness run 1). MEASURED in harness run 2: worst acceleration overshoot 1.9e-6, worst turn
-- overshoot 3.8e-8. 1e-4 is ~50x the worst measured and still ~10000x tighter than the quantities
-- under test, so it catches a real regression while ignoring float32 noise.
local EPSILON = 1e-4
local REACTION_LIMIT = 0.5 -- seconds; the Director's requirement, not a CONFIG value
-- docs/design/boar-ai.md is stricter than the requirement and that is the number worth defending:
-- at 0.5 s this test would still pass with SENSE_INTERVAL raised from 0.2 to 0.45, which is the
-- regression the tighter bound exists to catch (review round 3, finding 4).
local DESIGN_REACTION = 0.25

local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

local START = Vector3.new(0, 0, 0)

local function newBrain(seed: number?)
	return Brain.new(CONFIG, FIELD, START, Random.new(seed or 1))
end

local function obs(position: Vector3, threats, extra)
	local o = {
		position = position,
		velocity = Vector3.zero,
		threats = threats or {},
		waypoints = nil,
		pathFailed = false,
		blockedAhead = false,
	}
	for key, value in pairs(extra or {}) do
		o[key] = value
	end
	return o
end

local function threatAt(x: number, z: number)
	return { { id = "t", position = Vector3.new(x, 0, z) } }
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

return function()
	describe("boar brain: states and reaction", function()
		it("starts IDLE", function()
			expect(newBrain():state()).to.equal("IDLE")
		end)

		it("stays IDLE with a threat just outside the detection radius", function()
			local brain = newBrain()
			local threat = threatAt(CONFIG.DETECT_RADIUS + 1, 0)
			for _ = 1, 120 do
				brain:step(DT, obs(START, threat))
			end
			expect(brain:state()).to.equal("IDLE")
		end)

		it("enters FLEE within 0.5 s of a threat inside the detection radius", function()
			local brain = newBrain()
			local threat = threatAt(CONFIG.DETECT_RADIUS - 1, 0)
			local elapsed = 0
			while brain:state() ~= "FLEE" and elapsed < REACTION_LIMIT * 2 do
				brain:step(DT, obs(START, threat))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
			expect(elapsed <= REACTION_LIMIT).to.equal(true)
		end)

		it("returns to IDLE only after CALM_TIME beyond CALM_RADIUS", function()
			local brain = newBrain()
			for _ = 1, 30 do
				brain:step(DT, obs(START, threatAt(CONFIG.DETECT_RADIUS - 1, 0)))
			end
			expect(brain:state()).to.equal("FLEE")

			-- Just inside CALM_RADIUS: never calms down, however long we wait.
			local far = threatAt(CONFIG.CALM_RADIUS - 1, 0)
			for _ = 1, math.ceil((CONFIG.CALM_TIME + 2) / DT) do
				brain:step(DT, obs(START, far))
			end
			expect(brain:state()).to.equal("FLEE")

			-- Beyond it: calms down, but not before CALM_TIME.
			local away = threatAt(CONFIG.CALM_RADIUS + 10, 0)
			local waited = 0
			while brain:state() == "FLEE" and waited < CONFIG.CALM_TIME * 3 do
				brain:step(DT, obs(START, away))
				waited += DT
			end
			expect(brain:state()).to.equal("IDLE")
			expect(waited >= CONFIG.CALM_TIME).to.equal(true)
		end)

		it("does not flicker at exactly the detection radius", function()
			local brain = newBrain()
			local edge = threatAt(CONFIG.DETECT_RADIUS, 0)
			for _ = 1, 30 do
				brain:step(DT, obs(START, edge))
			end
			expect(brain:state()).to.equal("FLEE")
			-- CALM_RADIUS > DETECT_RADIUS, so sitting on the detection edge keeps it fleeing.
			for _ = 1, math.ceil((CONFIG.CALM_TIME + 2) / DT) do
				brain:step(DT, obs(START, edge))
			end
			expect(brain:state()).to.equal("FLEE")
		end)
	end)

	describe("boar brain: the route", function()
		local function firstPathRequest(position: Vector3, threats)
			local brain = newBrain()
			for _ = 1, 60 do
				local intent = brain:step(DT, obs(position, threats))
				if intent.pathRequest then
					return intent.pathRequest
				end
			end
			return nil
		end

		it("routes to the exit line, inside the bounds minus the edge margin", function()
			local target = firstPathRequest(START, threatAt(20, 20))
			expect(target).to.be.ok()
			expect(target.Z).to.equal(FIELD.exitZ)
			expect(target.X >= FIELD.bounds.minX + CONFIG.EDGE_MARGIN).to.equal(true)
			expect(target.X <= FIELD.bounds.maxX - CONFIG.EDGE_MARGIN).to.equal(true)
		end)

		it("routes to the opposite side in X from the threat", function()
			local position = Vector3.new(0, 0, 0)
			local right = firstPathRequest(position, threatAt(-20, 0)) -- threat to the west
			local left = firstPathRequest(position, threatAt(20, 0)) -- threat to the east
			expect(right.X > position.X).to.equal(true)
			expect(left.X < position.X).to.equal(true)
		end)

		it("never routes through a threat standing between the boar and the exit", function()
			-- Boar at z = 0, exit at z = -190, threat at z = -30: in the way, and inside
			-- DETECT_RADIUS so the boar actually flees and asks for a path.
			local threat = threatAt(5, -30)
			local target = firstPathRequest(START, threat)
			expect(target).to.be.ok()
			expect(math.abs(target.X - 5) >= CONFIG.ROUTE_SIDE_BIAS * 2 - 1).to.equal(true)
		end)
	end)

	describe("boar brain: movement", function()
		it("increases the distance to the threat while fleeing", function()
			local brain = newBrain()
			local threat = Vector3.new(0, 0, 30)
			local position = START
			local before = nil
			for _ = 1, 120 do
				local intent = brain:step(DT, obs(position, { { id = "t", position = threat } }))
				position += intent.targetVelocity * DT
				if brain:state() == "FLEE" and not before then
					before = flatDistance(position, threat)
				end
			end
			expect(brain:state()).to.equal("FLEE")
			expect(flatDistance(position, threat) > before).to.equal(true)
		end)

		it("still moves when pathfinding fails", function()
			local brain = newBrain()
			local threat = threatAt(0, 30)
			local intent
			for _ = 1, 120 do
				intent = brain:step(DT, obs(START, threat, { pathFailed = true }))
			end
			expect(brain:state()).to.equal("FLEE")
			expect(intent.targetVelocity.Magnitude > 0).to.equal(true)
		end)

		it("turns aside when the probe says something is ahead", function()
			local brain = newBrain()
			local before = brain:debug().heading
			local turned = false
			for _ = 1, 2 * math.ceil(CONFIG.SENSE_INTERVAL / DT) do
				brain:step(DT, obs(START, {}, { blockedAhead = true }))
				if
					math.abs(
						math.atan2(
							before.X * brain:debug().heading.Z - before.Z * brain:debug().heading.X,
							before.X * brain:debug().heading.X + before.Z * brain:debug().heading.Z
						)
					) >= 1
				then
					turned = true
				end
			end
			expect(turned).to.equal(true)
		end)

		-- Largest single-tick change of the output direction over `ticks` steps, with the boar's
		-- position supplied by `positionAt`. The ordinary slew can only ever produce TURN_RATE * DT,
		-- so anything much larger can only have come from the anti-stuck turn.
		local function biggestTurn(seed: number, ticks: number, positionAt: (number) -> Vector3)
			local brain = newBrain(seed)
			local threat = threatAt(0, 30)
			local previous, biggest = nil, 0
			for tick = 1, ticks do
				local intent = brain:step(DT, obs(positionAt(tick), threat))
				local facing = intent.facing
				if previous and facing then
					biggest = math.max(
						biggest,
						math.abs(
							math.atan2(
								previous.X * facing.Z - previous.Z * facing.X,
								previous.X * facing.X + previous.Z * facing.Z
							)
						)
					)
				end
				previous = facing
			end
			return biggest, brain
		end

		it("turns hard when it is stuck against something", function()
			-- Round 1 wrote this turn onto an internal heading (dead); round 2 wrote it onto a local
			-- that the slew immediately overrode (a 3.8-degree nudge). It has to survive to the output,
			-- so assert the MAGNITUDE: only the stuck branch can move the facing further in one tick
			-- than TURN_RATE * DT (review round 2, findings 1 and 2).
			local ticks = math.ceil(CONFIG.STUCK_TIME * 3 / DT)
			local pinned, brain = biggestTurn(5, ticks, function()
				return START -- never moves: stuck
			end)
			expect(brain:state()).to.equal("FLEE")
			expect(pinned > 1).to.equal(true) -- radians; the turn is pi/2
		end)

		it("does not turn hard when it is moving freely", function()
			-- The control for the test above: same threat and seed, but a boar that is covering ground.
			-- It must stay ALIVE and inside the arena for the whole window, or the control measures
			-- nothing: the first version drove it straight over the exit line on tick 64, where the
			-- brain goes GONE and stops emitting a facing (review round 3, finding 1). A circle of
			-- radius 30 at 1 rad/s covers ~50 studs per STUCK_TIME -- far more than STUCK_DIST -- while
			-- staying near the origin and always inside CALM_RADIUS of the threat.
			local ticks = math.ceil(CONFIG.STUCK_TIME * 3 / DT)
			local moving, brain = biggestTurn(5, ticks, function(tick)
				local angle = tick * DT
				return Vector3.new(30 * math.cos(angle), 0, 30 * math.sin(angle))
			end)
			expect(brain:state()).to.equal("FLEE") -- never despawned, so the window was really measured
			expect(moving <= CONFIG.TURN_RATE * DT + EPSILON).to.equal(true)
		end)

		-- Both limits measured over the same run, with the boar CIRCLING: it must not be held still,
		-- because standing still for 2 * STUCK_TIME is by definition stuck and the anti-stuck branch
		-- then turns it 90 degrees in one tick -- which is what the two tests below used to trip over
		-- (Task 18 harness run 1). A circle of radius 30 at 1 rad/s covers far more than STUCK_DIST per
		-- STUCK_TIME, stays inside CALM_RADIUS of the threat, and never approaches the bounds.
		local function worstDeltas(seed: number, ticks: number)
			local brain = newBrain(seed)
			local threat = threatAt(0, 30)
			local previousSpeed, previousFacing = 0, nil
			local worstAccel, worstTurn = 0, 0
			for tick = 1, ticks do
				local angle = tick * DT
				local position = Vector3.new(30 * math.cos(angle), 0, 30 * math.sin(angle))
				local intent = brain:step(DT, obs(position, threat))

				local speed = intent.targetVelocity.Magnitude
				worstAccel = math.max(worstAccel, speed - previousSpeed)
				previousSpeed = speed

				local facing = intent.facing
				if previousFacing and facing then
					worstTurn = math.max(
						worstTurn,
						math.abs(
							math.atan2(
								previousFacing.X * facing.Z - previousFacing.Z * facing.X,
								previousFacing.X * facing.X + previousFacing.Z * facing.Z
							)
						)
					)
				end
				previousFacing = facing
			end
			return worstAccel, worstTurn, brain
		end

		it("never accelerates faster than ACCEL", function()
			local worstAccel, _, brain = worstDeltas(2, 300)
			expect(brain:state()).to.equal("FLEE")
			expect(worstAccel <= CONFIG.ACCEL * DT + EPSILON).to.equal(true)
		end)

		it("never turns faster than TURN_RATE", function()
			local _, worstTurn, brain = worstDeltas(2, 300)
			expect(brain:state()).to.equal("FLEE")
			expect(worstTurn <= CONFIG.TURN_RATE * DT + EPSILON).to.equal(true)
		end)

		it("clamps a huge dt", function()
			local a, b = newBrain(7), newBrain(7)
			local threat = threatAt(0, 30)
			local huge = a:step(5, obs(START, threat))
			local clamped = b:step(CONFIG.DT_CLAMP, obs(START, threat))
			expect(huge.targetVelocity.Magnitude <= clamped.targetVelocity.Magnitude + EPSILON).to.equal(true)
		end)

		it("wanders without leaving the home area", function()
			local brain = newBrain(3)
			local position = START
			local worst = 0
			for _ = 1, math.ceil(120 / DT) do
				local intent = brain:step(DT, obs(position, {}))
				position += intent.targetVelocity * DT
				worst = math.max(worst, flatDistance(position, START))
			end
			expect(brain:state()).to.equal("IDLE")
			expect(worst <= CONFIG.HOME_RADIUS + 20).to.equal(true)
		end)
	end)

	describe("boar brain: despawn", function()
		it("reports escaped exactly once when a fleeing boar crosses the exit line", function()
			local brain = newBrain()
			-- Get it fleeing first: "escaped" is a FLEE outcome (review round 2, finding 6).
			local threat = threatAt(0, 30)
			for _ = 1, 30 do
				brain:step(DT, obs(START, threat))
			end
			expect(brain:state()).to.equal("FLEE")

			local past = Vector3.new(0, 0, FIELD.exitZ - 1)
			local first = brain:step(DT, obs(past, threat))
			expect(first.despawn).to.equal(true)
			expect(first.reason).to.equal("escaped")
			expect(first.state).to.equal("GONE")

			local second = brain:step(DT, obs(past, threat))
			expect(second.despawn).to.equal(false)
			expect(second.state).to.equal("GONE")
			expect(second.targetVelocity.Magnitude).to.equal(0)
		end)

		it("does not despawn an idle boar that drifts over the exit line", function()
			local brain = newBrain()
			local past = Vector3.new(0, 0, FIELD.exitZ - 1)
			local intent = brain:step(DT, obs(past, {}))
			expect(intent.despawn).to.equal(false)
			expect(brain:state()).to.equal("IDLE")
		end)

		it("never despawns while idling at the real spawn point in the real arena", function()
			-- The production numbers, not this spec's: CONFIG.spawnPoint inside CONFIG.field. An
			-- idle wander must not reach the exit line, or the grey box loses its only boar before a
			-- driver ever arrives (review round 2, finding 6).
			local spawn = CONFIG.spawnPoint
			local brain = Brain.new(CONFIG, CONFIG.field, spawn, Random.new(9))
			local position = spawn
			for _ = 1, math.ceil(120 / DT) do
				local intent = brain:step(DT, obs(position, {}))
				expect(intent.despawn).to.equal(false)
				position += intent.targetVelocity * DT
			end
			expect(brain:state()).to.equal("IDLE")
		end)

		it("reports outOfBounds when it leaves the arena sideways", function()
			local brain = newBrain()
			local outside = Vector3.new(FIELD.bounds.maxX + CONFIG.BOUNDS_SLACK + 5, 0, 0)
			local intent = brain:step(DT, obs(outside, {}))
			expect(intent.despawn).to.equal(true)
			expect(intent.reason).to.equal("outOfBounds")
		end)

		it("reports outOfBounds when it falls through the world", function()
			local brain = newBrain()
			local fallen = Vector3.new(0, FIELD.groundY - CONFIG.FALL_LIMIT - 1, 0)
			local intent = brain:step(DT, obs(fallen, {}))
			expect(intent.despawn).to.equal(true)
			expect(intent.reason).to.equal("outOfBounds")
		end)
	end)

	-- Milestone 1.5: being shot. The Brain is told a SEVERITY and a direction, never a damage number,
	-- so everything here is about the REACTION -- and the reaction is what Karen's playtest asked
	-- for ("I cannot tell if I hit anything"). The model itself is boar_wound.spec.
	-- Design: docs/design/hit-zones.md (sections 6, 12.2)
	describe("boar brain: being shot", function()
		local WOUND = CONFIG.WOUND

		local function hitEvent(severity: string, from: Vector3?)
			return { severity = severity, zone = "body", from = from }
		end

		-- One step carrying hit events, with no threat anywhere in the world.
		local function shoot(brain, severity: string, from: Vector3?, position: Vector3?)
			return brain:step(DT, obs(position or START, {}, { hitEvents = { hitEvent(severity, from) } }))
		end

		it("drops on a lethal hit, on the SAME tick, and never moves again", function()
			local brain = newBrain()
			local intent = shoot(brain, "lethal")
			expect(brain:state()).to.equal("DOWN")
			expect(intent.downed).to.equal(true)
			expect(intent.targetVelocity.Magnitude).to.equal(0)

			-- downed is true EXACTLY once: a kill counted twice is a bug that looks like a cheat.
			for _ = 1, 120 do
				local later = brain:step(DT, obs(START, {}))
				expect(later.downed).to.equal(false)
				expect(later.targetVelocity.Magnitude).to.equal(0)
			end
		end)

		it("does not drop on a grazing hit, and is still running five seconds later", function()
			local brain = newBrain()
			local intent = shoot(brain, "grazed")
			expect(intent.downed).to.equal(false)
			expect(brain:state()).to.equal("FLEE")
			for _ = 1, 300 do
				brain:step(DT, obs(START, {}))
			end
			expect(brain:state()).never.to.equal("DOWN")
		end)

		it("reacts within ONE tick and skips the acceleration ramp, with no threat anywhere", function()
			local brain = newBrain()
			-- Sense first, so the boar is settled in IDLE and the sense accumulator has just reset:
			-- a reaction that waited for the next sense tick would be up to SENSE_INTERVAL late.
			brain:step(DT, obs(START, {}))
			expect(brain:state()).to.equal("IDLE")

			local intent = shoot(brain, "grazed", Vector3.new(0, 0, 40))
			expect(intent.state).never.to.equal("IDLE")
			local floor = CONFIG.SPRINT_SPEED * WOUND.BOLT_KICK * 0.9
			expect(intent.targetVelocity.Magnitude >= floor).to.equal(true)
		end)

		it("bolts AWAY from the shot, with no threat to run from", function()
			local brain = newBrain()
			local shot = Vector3.new(0, 0, 40)
			local position = START
			shoot(brain, "grazed", shot, position)
			local before = flatDistance(position, shot)
			for _ = 1, 30 do
				local intent = brain:step(DT, obs(position, {}, { hitEvents = {} }))
				position += intent.targetVelocity * DT
			end
			expect(flatDistance(position, shot) > before).to.equal(true)
		end)

		it("stays WOUNDED: a mortally wounded animal does not go back to grazing", function()
			local brain = newBrain()
			shoot(brain, "mortal")
			expect(brain:state()).to.equal("WOUNDED")
			-- 30 s with no threat within CALM_RADIUS. A FLEE boar calms in CALM_TIME, which the
			-- existing "returns to IDLE" test asserts -- so the two together prove the difference is
			-- the wound and not the timer.
			for _ = 1, 1800 do
				brain:step(DT, obs(START, {}))
			end
			expect(brain:state()).to.equal("WOUNDED")
		end)

		it("still routes to the exit line while wounded, using the FLEE rule unchanged", function()
			local brain = newBrain()
			shoot(brain, "mortal", Vector3.new(0, 0, 40))
			local request = nil
			for _ = 1, 60 do
				local intent = brain:step(DT, obs(START, {}))
				request = intent.pathRequest or request
			end
			expect(request).to.be.ok()
			expect(request.Z).to.equal(FIELD.exitZ)
			expect(request.X >= FIELD.bounds.minX + CONFIG.EDGE_MARGIN).to.equal(true)
			expect(request.X <= FIELD.bounds.maxX - CONFIG.EDGE_MARGIN).to.equal(true)
		end)

		it("scales the speed setpoint by the wound, and still respects the ACCEL ramp", function()
			local function steadySpeed(scale: number?): number
				local brain = newBrain()
				local threat = threatAt(10, 0) -- inside DETECT_RADIUS, so it sprints
				local extra = if scale then { wound = { severity = "mortal", speedScale = scale } } else nil
				local last, speed = 0, 0
				for _ = 1, 600 do
					local intent = brain:step(DT, obs(START, threat, extra))
					speed = intent.targetVelocity.Magnitude
					-- The ramp is bypassed exactly once, on a hit tick; there is no hit here.
					expect(speed - last <= CONFIG.ACCEL * DT + EPSILON).to.equal(true)
					last = speed
				end
				return speed
			end

			local full = steadySpeed(nil)
			local half = steadySpeed(0.5)
			expect(math.abs(full - CONFIG.SPRINT_SPEED) < 0.5).to.equal(true)
			expect(math.abs(half - full / 2) < 0.5).to.equal(true)
		end)

		it("collapses when the wound says so, once, and then holds still", function()
			local brain = newBrain()
			shoot(brain, "mortal")
			for _ = 1, 60 do
				brain:step(DT, obs(START, {}))
			end
			expect(brain:state()).to.equal("WOUNDED")

			local collapse = brain:step(DT, obs(START, {}, { wound = { severity = "mortal", collapse = true } }))
			expect(brain:state()).to.equal("DOWN")
			expect(collapse.downed).to.equal(true)
			local after = brain:step(DT, obs(START, {}, { wound = { severity = "mortal", collapse = true } }))
			expect(after.downed).to.equal(false)
			expect(after.targetVelocity.Magnitude).to.equal(0)
		end)

		it("becomes a carcass for CARCASS_SECONDS, then despawns once as killed", function()
			local brain = newBrain()
			shoot(brain, "lethal")

			local ticks = math.floor(WOUND.CARCASS_SECONDS / DT) - 10
			for _ = 1, ticks do
				local intent = brain:step(DT, obs(START, {}))
				expect(intent.despawn).to.equal(false) -- the carcass IS the point: it stays
			end

			local despawns, reason = 0, nil
			for _ = 1, 120 do
				local intent = brain:step(DT, obs(START, {}))
				if intent.despawn then
					despawns += 1
					reason = intent.reason
				end
			end
			expect(despawns).to.equal(1)
			expect(reason).to.equal("killed")
			expect(brain:state()).to.equal("GONE")
		end)

		it("reports a WOUNDED boar over the exit line as an escape, not a kill", function()
			local brain = newBrain()
			shoot(brain, "mortal")
			expect(brain:state()).to.equal("WOUNDED")
			local outside = Vector3.new(0, 0, FIELD.exitZ - 1)
			local intent = brain:step(DT, obs(outside, {}))
			expect(intent.despawn).to.equal(true)
			expect(intent.reason).to.equal("escaped")
			expect(brain:step(DT, obs(outside, {})).despawn).to.equal(false) -- reported exactly once
		end)

		it("ignores hits once it is down or gone, and never re-animates", function()
			local brain = newBrain()
			shoot(brain, "lethal")
			expect(brain:state()).to.equal("DOWN")
			local intent = shoot(brain, "mortal", Vector3.new(0, 0, 40))
			expect(brain:state()).to.equal("DOWN")
			expect(intent.downed).to.equal(false)
			expect(intent.targetVelocity.Magnitude).to.equal(0)
		end)

		it("takes the most severe of several hits in one observation", function()
			local brain = newBrain()
			brain:step(
				DT,
				obs(START, {}, { hitEvents = { hitEvent("grazed"), hitEvent("lethal"), hitEvent("grazed") } })
			)
			expect(brain:state()).to.equal("DOWN")
		end)

		it("is still deterministic, and a hitch still cannot skip the whole flight", function()
			local a, b = newBrain(77), newBrain(77)
			for index = 1, 200 do
				local events = if index % 50 == 0 then { hitEvent("grazed", Vector3.new(0, 0, 40)) } else {}
				local ia = a:step(DT, obs(START, {}, { hitEvents = events }))
				local ib = b:step(DT, obs(START, {}, { hitEvents = events }))
				expect(ia.state).to.equal(ib.state)
				expect((ia.targetVelocity - ib.targetVelocity).Magnitude < 1e-9).to.equal(true)
			end

			-- dt is clamped, in DOWN as everywhere else: one 5-second hitch must not delete a carcass
			-- that should have lain there for two minutes.
			local brain = newBrain()
			shoot(brain, "lethal")
			for _ = 1, 10 do
				expect(brain:step(5, obs(START, {})).despawn).to.equal(false)
			end
		end)
	end)

	describe("boar brain: determinism and cost", function()
		it("gives identical intents for the same seed", function()
			local a, b = newBrain(42), newBrain(42)
			local threat = threatAt(10, 10)
			for _ = 1, 200 do
				local ia = a:step(DT, obs(START, threat))
				local ib = b:step(DT, obs(START, threat))
				expect(ia.state).to.equal(ib.state)
				-- Tighter than EPSILON on purpose, and not for the same reason: two brains with the
				-- same seed execute the same operations on the same values, so their outputs are
				-- bit-identical. This asserts determinism, not a bound on a physical quantity, so
				-- float32 representation error does not enter (review round 5, finding 4).
				expect((ia.targetVelocity - ib.targetVelocity).Magnitude < 1e-9).to.equal(true)
			end
		end)

		it("steps 10000 times in under 100 ms", function()
			local brain = newBrain()
			local threat = threatAt(10, 10)
			local observation = obs(START, threat)
			local started = os.clock()
			for _ = 1, 10000 do
				brain:step(DT, observation)
			end
			expect(os.clock() - started < 0.1).to.equal(true)
		end)
	end)
end
