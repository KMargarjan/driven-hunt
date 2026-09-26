-- boar_sounder.spec: the FOLLOWER's decisions, with no physics, no Workspace and no waiting.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- The sounder reaches the Brain as `obs.sounder` -- plain values, no reference to another boar --
-- which is exactly what lets this file drive a formation with hand-written tables and a fixed
-- Random. Both states of the feature are testable while the flag sits at one of them, because
-- nothing here reads the flag: a follower exists when the observation says so.
--
-- Design: docs/design/drive.md ("the sounder's behaviour, and who writes it";
--         "boar_sounder.spec.luau -- NEW, pure")
-- Note:   docs/research/2026-09-25-drive.md (Addendum 2)
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Brain = Boar.Brain
local CONFIG = Boar.CONFIG
local SOUNDER = CONFIG.SOUNDER

local DT = 1 / 60
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}
local START = Vector3.new(0, 0, 0)

local function newBrain(seed: number?)
	return Brain.new(CONFIG, FIELD, START, Random.new(seed or 1))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

-- A leader running toward the exit line at sprint, which is what a driven sounder's leader does.
local function leaderAt(position: Vector3, speed: number?)
	local forward = Vector3.new(0, 0, -1)
	local fast = speed or CONFIG.SPRINT_SPEED
	return {
		position = position,
		velocity = forward * fast,
		facing = forward,
		speed = fast,
	}
end

local function sounderObs(overrides)
	local sounder = {
		isLeader = false,
		slot = 2,
		scattering = false,
		leaderState = "FLEE",
		leader = leaderAt(Vector3.new(0, 0, -20)),
		centroid = Vector3.new(0, 0, -10),
		neighbours = {},
	}
	for key, value in pairs(overrides or {}) do
		sounder[key] = value
	end
	return sounder
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

-- Where slot `slot` stands when the leader faces -Z from `leaderPosition`: the FORMATION offset is
-- in the leader's frame, +Z behind it. Written out here rather than taken from the code, so a
-- change to the frame shows up as a failure instead of cancelling out.
local function slotPoint(leaderPosition: Vector3, slot: number): Vector3
	local offset = SOUNDER.FORMATION[slot]
	-- leader faces -Z, so "behind" is +Z, and the leader's right is -X.
	return Vector3.new(leaderPosition.X - offset.X, 0, leaderPosition.Z + offset.Z)
end

return function()
	describe("boar sounder: the follower does not path", function()
		it("never asks for a route, however long it flees", function()
			local brain = newBrain()
			local requests = 0
			for step = 1, 600 do
				local intent =
					brain:step(DT, obs(Vector3.new(0, 0, step * 0.01), threatAt(0, 40), { sounder = sounderObs() }))
				if intent.pathRequest then
					requests += 1
				end
			end
			expect(requests).to.equal(0)
		end)

		it("but a LEADER does, on the exit line and clear of the threat", function()
			local brain = newBrain()
			local request = nil
			for _ = 1, 60 do
				local intent = brain:step(
					DT,
					obs(
						START,
						threatAt(0, 30),
						{ sounder = sounderObs({ isLeader = true, slot = 1, leader = nil, leaderState = nil }) }
					)
				)
				request = intent.pathRequest or request
			end
			expect(request).to.be.ok()
			expect(request.Z).to.equal(FIELD.exitZ)
			expect(request.X >= FIELD.bounds.minX + CONFIG.EDGE_MARGIN).to.equal(true)
			expect(request.X <= FIELD.bounds.maxX - CONFIG.EDGE_MARGIN).to.equal(true)
		end)
	end)

	describe("boar sounder: formation", function()
		it("closes a 30-stud gap to its slot and then stays inside the tolerance", function()
			-- The leader is held still: this is about the follower's steering, not about chasing.
			local leader = leaderAt(Vector3.new(0, 0, -40), CONFIG.TROT_SPEED)
			local target = slotPoint(leader.position, 2)
			local position = target + Vector3.new(30, 0, 0)
			local brain = newBrain()
			local heading = nil
			local reversals = 0

			for _ = 1, 600 do
				local intent = brain:step(
					DT,
					obs(position, {}, {
						sounder = sounderObs({ leader = leader, centroid = leader.position }),
					})
				)
				local velocity = intent.targetVelocity
				position += velocity * DT
				if velocity.Magnitude > 1e-3 then
					local now = velocity.Unit
					if heading and now:Dot(heading) < 0 then
						reversals += 1
					end
					heading = now
				end
			end

			expect(flatDistance(position, slotPoint(leader.position, 2)) <= SOUNDER.SLOT_TOLERANCE_STUDS).to.equal(true)
			-- 600 steps is 10 simulated seconds; "less than once per second" is the design's bound.
			expect(reversals < 10).to.equal(true)
		end)

		it("puts the follower in COLUMN when the probe is blocked, and holds it after it clears", function()
			local leader = leaderAt(Vector3.new(0, 0, -40), CONFIG.TROT_SPEED)
			-- Slot 3 is +7 to the leader's right in the wedge and dead astern in the column, so the
			-- two formations disagree about where this member belongs -- which is what makes the
			-- direction the assertion.
			local position = Vector3.new(0, 0, 0)
			local blocked = newBrain()
			local wedge = newBrain()
			local column = sounderObs({ slot = 3, leader = leader, centroid = leader.position })

			local blockedIntent = blocked:step(DT, obs(position, {}, { sounder = column, blockedAhead = true }))
			local wedgeIntent = wedge:step(DT, obs(position, {}, { sounder = column }))
			expect(blockedIntent.facing).to.be.ok()
			expect(wedgeIntent.facing).to.be.ok()
			expect(blockedIntent.facing:Dot(wedgeIntent.facing) < 0.9999).to.equal(true)

			-- ...and the probe clearing does not end it: the latch holds for COLUMN_LATCH_SECONDS.
			local held = blocked:step(DT, obs(position, {}, { sounder = column }))
			local stillColumn = held.facing
			expect(stillColumn:Dot(blockedIntent.facing) > 0.99).to.equal(true)

			-- After the latch, it is a wedge again.
			local elapsed = DT
			while elapsed < SOUNDER.COLUMN_LATCH_SECONDS + 0.2 do
				blocked:step(DT, obs(position, {}, { sounder = column }))
				elapsed += DT
			end
			local after = blocked:step(DT, obs(position, {}, { sounder = column }))
			expect(after.facing:Dot(stillColumn) < 0.9999).to.equal(true)
		end)
	end)

	describe("boar sounder: separation", function()
		it("pushes two members apart even when the slot lies through each other", function()
			-- The slot is on the far side of the neighbour, so cohesion pulls straight INTO it.
			local leader = leaderAt(Vector3.new(0, 0, -40), CONFIG.TROT_SPEED)
			local position = Vector3.new(0, 0, 0)
			local neighbour = { position = Vector3.new(0, 0, -3), velocity = Vector3.zero }
			local brain = newBrain()
			local sounder = sounderObs({
				slot = 2,
				leader = leader,
				centroid = leader.position,
				neighbours = { neighbour },
			})

			local first = brain:step(DT, obs(position, {}, { sounder = sounder }))
			local before = flatDistance(position, neighbour.position)
			local moved = position + first.targetVelocity * DT
			expect(flatDistance(moved, neighbour.position) > before).to.equal(true)

			-- ...and the turn-rate limit is not bypassed on the way.
			local second = brain:step(DT, obs(moved, {}, { sounder = sounder }))
			local turn = math.acos(math.clamp(first.facing:Dot(second.facing), -1, 1))
			expect(turn <= CONFIG.TURN_RATE * DT + 1e-4).to.equal(true)
		end)
	end)

	describe("boar sounder: speed", function()
		it("matches the leader, never exceeds leader x CATCHUP, and never exceeds SPRINT_SPEED", function()
			local leader = leaderAt(Vector3.new(0, 0, -40), 20)
			local inPlace = slotPoint(leader.position, 2)
			local far = inPlace + Vector3.new(40, 0, 0)
			local ceiling = leader.speed * SOUNDER.CATCHUP

			local near = newBrain()
			local nearSpeed = 0
			for _ = 1, 600 do
				local intent = near:step(DT, obs(inPlace, {}, { sounder = sounderObs({ leader = leader }) }))
				nearSpeed = intent.targetVelocity.Magnitude
				expect(nearSpeed <= ceiling + 1e-3).to.equal(true)
				expect(nearSpeed <= CONFIG.SPRINT_SPEED + 1e-3).to.equal(true)
			end
			expect(math.abs(nearSpeed - leader.speed) <= 1).to.equal(true)

			local chasing = newBrain()
			local chaseSpeed = 0
			for _ = 1, 600 do
				local intent = chasing:step(DT, obs(far, {}, { sounder = sounderObs({ leader = leader }) }))
				chaseSpeed = intent.targetVelocity.Magnitude
				expect(chaseSpeed <= ceiling + 1e-3).to.equal(true)
			end
			-- ...and it really is catching up rather than merely not exceeding the ceiling.
			expect(chaseSpeed > leader.speed).to.equal(true)
		end)
	end)

	describe("boar sounder: scattering", function()
		it("drops cohesion and alignment, keeps moving, and spreads harder", function()
			local position = Vector3.new(0, 0, 0)
			local neighbour = { position = Vector3.new(4, 0, 0), velocity = Vector3.zero }
			local scattered = sounderObs({
				scattering = true,
				leader = nil,
				leaderState = nil,
				centroid = Vector3.new(60, 0, 0), -- far away, and it must not matter
				neighbours = { neighbour },
			})
			local elsewhere = sounderObs({
				scattering = true,
				leader = nil,
				leaderState = nil,
				centroid = Vector3.new(-60, 0, 0), -- the opposite way, and it must not matter either
				neighbours = { neighbour },
			})

			local a, b = newBrain(), newBrain()
			local first = a:step(DT, obs(position, threatAt(0, 30), { sounder = scattered }))
			local second = b:step(DT, obs(position, threatAt(0, 30), { sounder = elsewhere }))
			expect(first.facing:Dot(second.facing) > 0.9999).to.equal(true)
			expect(first.targetVelocity.Magnitude > 0).to.equal(true)

			-- ...and the push off the neighbour is stronger than it is in formation.
			local formation = newBrain()
			local held = formation:step(
				DT,
				obs(position, threatAt(0, 30), { sounder = sounderObs({ neighbours = { neighbour } }) })
			)
			local awayX = -1 -- the neighbour is at +X, so "apart" is -X
			expect(first.facing.X * awayX > held.facing.X * awayX).to.equal(true)
		end)
	end)

	describe("boar sounder: the herd panics and calms together", function()
		it("an IDLE follower bolts when its leader is fleeing, with no threat of its own", function()
			local brain = newBrain()
			local panicking = sounderObs({ leaderState = "FLEE" })
			local elapsed = 0
			while elapsed < CONFIG.SENSE_INTERVAL + DT * 2 do
				brain:step(DT, obs(START, {}, { sounder = panicking }))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
		end)

		it("...and stays IDLE when the leader is calm", function()
			local brain = newBrain()
			local calm = sounderObs({ leaderState = "IDLE" })
			for _ = 1, 600 do
				brain:step(DT, obs(START, {}, { sounder = calm }))
			end
			expect(brain:state()).to.equal("IDLE")
		end)

		it("does not settle while the leader is still running", function()
			local brain = newBrain()
			local running = sounderObs({ leaderState = "FLEE" })
			-- into FLEE first, with a threat of its own
			for _ = 1, 60 do
				brain:step(DT, obs(START, threatAt(0, 20), { sounder = running }))
			end
			expect(brain:state()).to.equal("FLEE")
			-- ...then no threat at all, for four times CALM_TIME
			for _ = 1, math.ceil(CONFIG.CALM_TIME * 4 / DT) do
				brain:step(DT, obs(START, {}, { sounder = running }))
			end
			expect(brain:state()).to.equal("FLEE")

			-- The same brain settles as soon as the leader has settled.
			local settled = sounderObs({ leaderState = "IDLE" })
			for _ = 1, math.ceil(CONFIG.CALM_TIME * 2 / DT) do
				brain:step(DT, obs(START, {}, { sounder = settled }))
			end
			expect(brain:state()).to.equal("IDLE")
		end)
	end)

	describe("boar sounder: a wounded follower", function()
		it("still runs, and its setpoint is scaled by the wound exactly as a lone boar's is", function()
			local leader = leaderAt(Vector3.new(0, 0, -40), CONFIG.SPRINT_SPEED)
			local scale = 0.5
			local wounded, whole = newBrain(), newBrain()
			local woundedSpeed, wholeSpeed = 0, 0
			for _ = 1, 600 do
				woundedSpeed = wounded:step(
					DT,
					obs(START, threatAt(0, 20), {
						sounder = sounderObs({ leader = leader }),
						wound = { severity = "mortal", speedScale = scale, collapse = false },
					})
				).targetVelocity.Magnitude
				wholeSpeed =
					whole:step(DT, obs(START, threatAt(0, 20), { sounder = sounderObs({ leader = leader }) })).targetVelocity.Magnitude
			end
			expect(woundedSpeed > 0).to.equal(true)
			expect(math.abs(woundedSpeed - wholeSpeed * scale) <= 0.5).to.equal(true)
		end)
	end)

	describe("boar sounder: the arithmetic holds", function()
		it("is deterministic: same seed, same observations, same intents", function()
			local a, b = newBrain(7), newBrain(7)
			for step = 1, 300 do
				local where = Vector3.new(step * 0.1, 0, 0)
				local sounder =
					sounderObs({ neighbours = { { position = Vector3.new(3, 0, 0), velocity = Vector3.zero } } })
				local first = a:step(DT, obs(where, threatAt(0, 30), { sounder = sounder }))
				local second = b:step(DT, obs(where, threatAt(0, 30), { sounder = sounder }))
				expect((first.targetVelocity - second.targetVelocity).Magnitude < 1e-6).to.equal(true)
				expect(first.state).to.equal(second.state)
			end
		end)

		it("clamps a 5-second frame to DT_CLAMP", function()
			local hitched, clamped = newBrain(), newBrain()
			local sounder = sounderObs()
			local a = hitched:step(5, obs(START, threatAt(0, 20), { sounder = sounder }))
			local b = clamped:step(CONFIG.DT_CLAMP, obs(START, threatAt(0, 20), { sounder = sounder }))
			expect(math.abs(a.targetVelocity.Magnitude - b.targetVelocity.Magnitude) < 1e-4).to.equal(true)
		end)

		it("runs 10000 follower steps in well under 150 ms", function()
			local brain = newBrain()
			local sounder = sounderObs({
				neighbours = {
					{ position = Vector3.new(6, 0, 0), velocity = Vector3.zero },
					{ position = Vector3.new(-6, 0, 2), velocity = Vector3.zero },
					{ position = Vector3.new(0, 0, 8), velocity = Vector3.zero },
					{ position = Vector3.new(3, 0, -6), velocity = Vector3.zero },
				},
			})
			local started = os.clock()
			for step = 1, 10000 do
				brain:step(DT, obs(Vector3.new(step * 0.001, 0, 0), threatAt(0, 30), { sounder = sounder }))
			end
			expect((os.clock() - started) * 1000 < 150).to.equal(true)
		end)
	end)
end
