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
			-- IT HAS TO BE MOVING. A follower pinned in one place is STUCK, and the stuck rule is
			-- the one documented exception to LEADER_PATHS_ONLY -- a member wedged behind a trunk
			-- may ask once, because the sidestep alone does not always clear it. Integrating the
			-- intent is also what a body does with it, so this is the honest test.
			local brain = newBrain()
			local position = START
			local requests = 0
			for _ = 1, 600 do
				local intent = brain:step(DT, obs(position, threatAt(0, 40), { sounder = sounderObs() }))
				position += intent.targetVelocity * DT
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
			-- THE LEADER MOVES, and it has to: a follower also carries the flee term (0.8) and the
			-- alignment term (0.4), which point where the SOUNDER is going. Behind a leader that is
			-- actually going somewhere they agree with cohesion and the formation closes; behind a
			-- leader standing still they fight it, and the follower orbits its slot instead of
			-- sitting in it. Measured in Edit, 2026-09-26: 30 studs -> 4.98 by second 3, then
			-- 4.9 / 4.99 / 5.06 / 5.16 / 4.79 / 4.75 at seconds 4 to 9.
			local speed = CONFIG.TROT_SPEED
			local leaderPosition = Vector3.new(0, 0, -40)
			local position = slotPoint(leaderPosition, 2) + Vector3.new(30, 0, 0)
			local opened = flatDistance(position, slotPoint(leaderPosition, 2))
			local brain = newBrain()
			local heading = nil
			local reversals = 0
			local worstLate = 0

			for step = 1, 480 do
				local intent = brain:step(
					DT,
					obs(position, {}, {
						sounder = sounderObs({
							leader = leaderAt(leaderPosition, speed),
							centroid = leaderPosition,
						}),
					})
				)
				position += intent.targetVelocity * DT
				leaderPosition += Vector3.new(0, 0, -1) * speed * DT
				if step > 240 then
					worstLate = math.max(worstLate, flatDistance(position, slotPoint(leaderPosition, 2)))
				end
				local velocity = intent.targetVelocity
				if velocity.Magnitude > 1e-3 then
					local now = velocity.Unit
					if heading and now:Dot(heading) < 0 then
						reversals += 1
					end
					heading = now
				end
			end

			expect(opened > 25).to.equal(true) -- it really did start out of position
			-- ...and it is IN the formation for the whole second half, not merely once at the end.
			expect(worstLate <= SOUNDER.SLOT_TOLERANCE_STUDS + 0.5).to.equal(true)
			-- No oscillation: 8 seconds, and the measured run reverses not once.
			expect(reversals < 8).to.equal(true)
		end)

		it("puts the follower in COLUMN when the probe is blocked, and holds it after it clears", function()
			-- INTEGRATED, not compared one step at a time: `facing` is slewed by at most
			-- TURN_RATE * dt (3.8 degrees at 60 Hz), so after a single step two brains that want
			-- opposite things still look almost identical. Where they have GOT TO after a second is
			-- the difference the formation makes. Slot 3 stands +7 to the leader's right in the
			-- wedge and dead astern in the column, so the two disagree about where it belongs.
			local leaderPosition = Vector3.new(0, 0, -40)
			local leader = leaderAt(leaderPosition, CONFIG.TROT_SPEED)

			local function run(blockUntil: number): Vector3
				local brain = newBrain()
				local position = START
				for step = 1, 60 do
					local intent = brain:step(
						DT,
						obs(position, {}, {
							sounder = sounderObs({ slot = 3, leader = leader, centroid = leaderPosition }),
							blockedAhead = step <= blockUntil,
						})
					)
					position += intent.targetVelocity * DT
				end
				return position
			end

			-- Blocked on the FIRST STEP ONLY: everything after it is the latch, not the probe.
			local column = run(1)
			local wedge = run(0)
			expect(flatDistance(column, wedge) > 1).to.equal(true)
		end)
	end)

	describe("boar sounder: separation", function()
		it("pushes two members apart even when the slot lies through each other", function()
			-- The slot is on the far side of the neighbour, so cohesion pulls straight INTO it and
			-- only separation can win. Measured in Edit, 2026-09-26: 3 studs -> 23.43 in 1.5 s,
			-- with the worst turn between consecutive steps exactly TURN_RATE * dt.
			local leaderPosition = Vector3.new(0, 0, -40)
			local position = START
			local neighbour = { position = Vector3.new(0, 0, -3), velocity = Vector3.zero }
			local brain = newBrain()
			local sounder = sounderObs({
				slot = 2,
				leader = leaderAt(leaderPosition, CONFIG.TROT_SPEED),
				centroid = leaderPosition,
				neighbours = { neighbour },
			})

			local before = flatDistance(position, neighbour.position)
			local previous = nil
			local worstTurn = 0
			for _ = 1, 90 do
				local intent = brain:step(DT, obs(position, {}, { sounder = sounder }))
				position += intent.targetVelocity * DT
				if previous then
					worstTurn = math.max(worstTurn, math.acos(math.clamp(intent.facing:Dot(previous), -1, 1)))
				end
				previous = intent.facing
			end

			expect(flatDistance(position, neighbour.position) > before * 3).to.equal(true)
			-- ...and the turn-rate limit is not bypassed on the way out.
			expect(worstTurn <= CONFIG.TURN_RATE * DT + 1e-4).to.equal(true)
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
			-- INTEGRATED for a second, for the same reason the column case is: one slewed step of
			-- two brains that want opposite things still looks almost identical.
			-- Measured in Edit, 2026-09-26: the two centroids end in EXACTLY the same place
			-- (0.000 studs apart), and the scattering member is 6.88 studs the far side of the
			-- neighbour where the one in formation is 0.69 studs the near side.
			local neighbour = { position = Vector3.new(4, 0, 0), velocity = Vector3.zero }

			local function run(scattering: boolean, centroid: Vector3): Vector3
				local brain = newBrain()
				local position = START
				for _ = 1, 60 do
					local sounder = sounderObs({
						scattering = scattering,
						leader = if scattering then nil else leaderAt(Vector3.new(0, 0, -40), CONFIG.TROT_SPEED),
						leaderState = if scattering then nil else "FLEE",
						centroid = centroid,
						neighbours = { neighbour },
					})
					local intent = brain:step(DT, obs(position, threatAt(0, 30), { sounder = sounder }))
					position += intent.targetVelocity * DT
				end
				return position
			end

			-- The centroid is 120 studs apart between these two runs and it must change NOTHING:
			-- while scattering there is nothing to cohere to.
			local toward = run(true, Vector3.new(60, 0, 0))
			local away = run(true, Vector3.new(-60, 0, 0))
			expect(flatDistance(toward, away) < 1e-3).to.equal(true)
			-- ...it never freezes,
			expect(flatDistance(toward, START) > 1).to.equal(true)
			-- ...and it pushes off its neighbour harder than a member in formation does.
			local held = run(false, Vector3.new(0, 0, -40))
			expect(toward.X < held.X - 2).to.equal(true)
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
