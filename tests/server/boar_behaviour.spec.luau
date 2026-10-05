-- boar_behaviour.spec: WHEN A BOAR LEAVES BEING CALM, and what it does about it (task 118).
-- Pure: no physics, no Workspace, no waiting. Every band, every timer and every transition is driven
-- through `Brain:step(1/60, obs)` with hand-written observations, or through the exported pure
-- functions with no boar at all.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- THE FLAG ARRIVES AS A PARAMETER, which is the one permitted shape and the only way both states are
-- reachable: `python tools/studio_mcp.py test` REFUSES to start while an override is set, so a
-- harness run can only ever see `BOAR_BEHAVIOUR`'s OFF default. Every case below passes its own
-- `SENSE` block, and the OFF cases are the ones that prove the live game is unchanged.
--
-- Numbers are written out where the requirement is absolute (the 0.25 s reaction, the 25/60 split)
-- and read from CONFIG where the assertion is a RELATIONSHIP -- the convention `boar_brain.spec`
-- follows, for the same reason.
-- Design: docs/design/boar-behaviour.md (section 12, the pure half)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Brain = Boar.Brain
local CONFIG = Boar.CONFIG
local SENSE = CONFIG.SENSE

local DT = 1 / 60
local DESIGN_REACTION = 0.25 -- SENSE_INTERVAL + one frame, the design's own budget
local EPSILON = 1e-4 -- float32 noise on a magnitude near SPRINT_SPEED (see boar_brain.spec)

local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}
local START = Vector3.new(0, 0, 0)

-- The whole SENSE block with `ENABLED` set and anything else overridden, merged key by key -- the
-- same merge `Boar.newRuntime` does, because a replaced block leaves every radius nil (case 14).
local function configWith(on: boolean, overrides)
	local sense = table.clone(SENSE)
	sense.ENABLED = on
	for key, value in pairs(overrides or {}) do
		sense[key] = value
	end
	local config = table.clone(CONFIG)
	config.SENSE = sense
	return config
end

-- ...and the same thing for `PACE`, which is a BLOCK OF ITS OWN and is replaced wholesale rather
-- than merged (task 123 round 2, `Boar.newRuntime`): the config a world passes IS the block.
local function paceConfig(on: boolean, senseOn: boolean?)
	local config = configWith(if senseOn == nil then true else senseOn)
	local pace = table.clone(CONFIG.PACE)
	pace.ENABLED = on
	config.PACE = pace
	return config
end

-- `phantom` IS PART OF A STIMULUS since task 123 round 5: it is the drive's mark on a beater it
-- invented, and a real driver never carries it. The two behave differently inside
-- `PACE.DRIVER_RUN_STUDS`, so a case has to say which it means.
local function stimulus(distance: number, kind: string?, speed: number?, phantom: boolean?)
	return { id = "s", position = Vector3.new(distance, 0, 0), kind = kind, speed = speed, phantom = phantom }
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

-- A FOLLOWER'S sounder observation, in the shape `Runtime:_sounderObs` builds it.
local function follower(extra)
	local o = {
		isLeader = false,
		slot = 2,
		scattering = false,
		leaderState = nil,
		leader = {
			position = Vector3.new(0, 0, 12),
			velocity = Vector3.zero,
			facing = Vector3.new(0, 0, 1),
			speed = 0,
		},
		centroid = Vector3.new(0, 0, 6),
		neighbours = {},
		formation = "wedge",
		alarm = false,
	}
	for key, value in pairs(extra or {}) do
		o[key] = value
	end
	return o
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- Steps the brain `steps` times, INTEGRATING the position from the intent so a case about getting
-- away from something can measure the distance it got. `threatsFor(step)` returns the stimulus list
-- for that step, so a case can move, stop or remove the cause mid-run.
local function drive(brain, steps: number, threatsFor, start: Vector3, extraFor)
	local position = start
	local intents = {}
	for step = 1, steps do
		local intent = brain:step(DT, obs(position, threatsFor(step), extraFor and extraFor(step) or nil))
		position += intent.targetVelocity * DT
		table.insert(intents, { intent = intent, position = position })
	end
	return intents, position
end

return function()
	-- ------------------------------------------------------------------ 1. the flag off
	describe("boar behaviour: with the flag OFF it is the world Milestone 1.2 shipped", function()
		local off = configWith(false)

		it("cannot see a shooter at all, however long he stands there", function()
			-- `MatchBoot` now hands the boar world the SHOOTERS as well (section 8), and this is the
			-- whole of what keeps that from changing the live game: a stimulus whose kind is not
			-- "driver" is dropped before any radius is consulted.
			--
			-- 24 STUDS IS THE DISTANCE THAT MAKES THIS A TEST. It is inside NOTICE_STANDING = 25, so
			-- with the flag on the animal goes head-up; and it is inside DETECT_RADIUS = 40, so if
			-- the kind filter were deleted the flag-OFF boar would BOLT rather than merely notice
			-- something. One stimulus, two states, and neither answer can be reached by accident.
			local brain = Brain.new(off, FIELD, START, Random.new(1))
			local shooter = { stimulus(24, "shooter") }
			for _ = 1, 600 do
				brain:step(DT, obs(START, shooter))
			end
			expect(brain:state()).to.equal("IDLE")

			local on = Brain.new(configWith(true), FIELD, START, Random.new(1))
			for _ = 1, 60 do
				on:step(DT, obs(START, shooter))
			end
			expect(on:state()).to.equal("ALERT")
		end)

		it("still flushes at DETECT_RADIUS, with the same 0.25 s budget", function()
			local brain = Brain.new(off, FIELD, START, Random.new(1))
			local driver = { stimulus(CONFIG.DETECT_RADIUS - 1, "driver") }
			local elapsed = 0
			while brain:state() ~= "FLEE" and elapsed < 1 do
				brain:step(DT, obs(START, driver))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
			-- ...and a standing driver one stud FURTHER OUT is still nothing, because with the flag
			-- off there is no notice band at all: the only two answers are flee and none.
			local calm = Brain.new(off, FIELD, START, Random.new(1))
			for _ = 1, 120 do
				calm:step(DT, obs(START, { stimulus(CONFIG.DETECT_RADIUS + 1, "driver") }))
			end
			expect(calm:state()).to.equal("IDLE")
		end)

		it("still panics a follower off its LEADER, which is the rule the flag replaces", function()
			local brain = Brain.new(off, FIELD, START, Random.new(1))
			local sounder = follower({ leaderState = "FLEE" })
			local elapsed = 0
			while brain:state() ~= "FLEE" and elapsed < 1 do
				brain:step(DT, obs(START, {}, { sounder = sounder }))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
		end)
	end)

	-- ------------------------------------------------------------------ 1b. a push is not a spook
	describe("boar behaviour: a pushed animal walks and a spooked one runs (task 123)", function()
		local PACE = CONFIG.PACE
		local on = paceConfig(true)
		local off = paceConfig(false)

		-- The pace is a clamp on the SETPOINT, and the setpoint is ramped by ACCEL -- so a case about
		-- which speed was ASKED FOR has to let the ramp finish. 2 s is three times the 0.63 s a
		-- sprint takes and a hundred times the 0.07 s a walk does.
		local function settledSpeed(config, threats)
			local brain = Brain.new(config, FIELD, START, Random.new(7))
			local intents = drive(brain, math.ceil(2 / DT), function()
				return threats
			end, START)
			local last = intents[#intents].intent
			return last.targetVelocity.Magnitude, brain:state()
		end

		-- A PUSHER THAT KEEPS PUSHING (task 129). `settledSpeed` holds its threat at a fixed WORLD
		-- point, so an animal asked to run leaves it behind in a few frames -- at 24 studs/s a driver
		-- 24 studs away is 70 studs behind before the ACCEL ramp has finished, and the speed the case
		-- then reads is the speed of an animal with nothing near it. That is why four of these cases
		-- could never be green whichever way the code went.
		--
		-- A driver drives: he STAYS behind the animal. This keeps the stimulus `distance` studs behind
		-- it every step, which is what a beater walking a sounder on actually does, and returns the
		-- speed once the ramp has settled.
		local function pushedSpeed(config, distance: number, phantom: boolean?)
			local brain = Brain.new(config, FIELD, START, Random.new(7))
			local position = START
			local last
			for _ = 1, math.ceil(2 / DT) do
				local behind = Vector3.new(position.X + distance, 0, position.Z)
				last = brain:step(
					DT,
					obs(
						position,
						{ { id = "pusher", position = behind, kind = "driver", speed = 5, phantom = phantom } }
					)
				)
				position += last.targetVelocity * DT
			end
			return last.targetVelocity.Magnitude, brain:state()
		end

		it("reports a spook only for something that is NOT a driver", function()
			-- The beater is ALWAYS the closer of the two by construction (it is placed 11 studs
			-- behind the rearmost animal against a 15-stud flush radius), so `reaction`'s
			-- single best cause can never be the hunter -- which is why `spook` is its own answer.
			local both = Brain.perceive(START, {
				{ id = "beater", position = Vector3.new(11, 0, 0), kind = "driver", speed = 5 },
				{ id = "hunter", position = Vector3.new(25, 0, 0), kind = "shooter", speed = 0 },
			}, on)
			expect(both.reaction).to.equal("flee")
			expect(both.cause.id).to.equal("beater")
			expect(both.spook).to.equal(true)
			-- THE DRIVE'S OWN BEATER at the same distance is a push and not a spook -- and since task
			-- 123 round 5 it has to carry `phantom = true` to be one. Karen asked for a REAL driver
			-- on top of an animal to make it run (*"if driver is close they run"*), so "driver" alone
			-- inside `DRIVER_RUN_STUDS` IS a spook now; the mark is what the Forest Test's invented
			-- beaters carry (`ForestTest.boarThreats`) and a player never does.
			local pushed = Brain.perceive(START, {
				{ id = "beater", position = Vector3.new(11, 0, 0), kind = "driver", speed = 5, phantom = true },
				{ id = "second", position = Vector3.new(25, 0, 0), kind = "driver", speed = 5, phantom = true },
			}, on)
			expect(pushed.reaction).to.equal("flee")
			expect(pushed.spook).to.equal(false)
			-- ...and the same two WITHOUT the mark are two real drivers on top of it, which is a run.
			local real = Brain.perceive(START, {
				{ id = "beater", position = Vector3.new(11, 0, 0), kind = "driver", speed = 5 },
				{ id = "second", position = Vector3.new(25, 0, 0), kind = "driver", speed = 5 },
			}, on)
			expect(real.spook).to.equal(true)
			-- A hunter one stud outside `SPOOK_STUDS` is not one either...
			local far = Brain.perceive(START, {
				{ id = "hunter", position = Vector3.new(PACE.SPOOK_STUDS + 1, 0, 0), kind = "shooter", speed = 0 },
			}, on)
			expect(far.spook).to.equal(false)
			-- ...and with PACE off nothing is ever a spook, so the field cannot change the old world.
			local none = Brain.perceive(START, {
				{ id = "hunter", position = Vector3.new(5, 0, 0), kind = "shooter", speed = 0 },
			}, off)
			expect(none.spook).to.equal(false)
		end)

		it("runs from a REAL driver this close, and never from the phantom beater", function()
			-- KAREN, 2026-10-05: "when driver is close or shoot is made they run". Round 2 made a
			-- driver a PUSH and nothing else, which is right for the approach and wrong for the
			-- moment a man walks onto the animal.
			--
			-- THE WHOLE DIFFICULTY IS TELLING THEM APART, and it is a pure case because it has to
			-- be: the Forest Test's beater stands 11 studs behind the rearmost animal BY
			-- CONSTRUCTION, so a rule that ran from any close driver would run every wave for its
			-- whole crossing. The drive MARKS its own invention; a player never carries the mark.
			local close = PACE.DRIVER_RUN_STUDS - 1
			local real = Brain.perceive(START, {
				{ id = "42", position = Vector3.new(close, 0, 0), kind = "driver", speed = 5 },
			}, on)
			expect(real.spook).to.equal(true)

			local beater = Brain.perceive(START, {
				{ id = "beater-3", position = Vector3.new(close, 0, 0), kind = "driver", speed = 5, phantom = true },
			}, on)
			expect(beater.spook).to.equal(false)
			-- ...and it is still a PUSH, so the herd keeps moving: the mark removes the run, not the
			-- drive.
			expect(beater.reaction).to.equal("flee")

			-- A real driver one stud further out is the push again, which is what makes the distance
			-- the thing under test rather than the kind.
			local far = Brain.perceive(START, {
				{ id = "42", position = Vector3.new(PACE.DRIVER_RUN_STUDS + 1, 0, 0), kind = "driver", speed = 5 },
			}, on)
			expect(far.spook).to.equal(false)
			-- ...and with PACE off nothing is ever a spook, so the DEV drive cannot change.
			expect(Brain.perceive(START, {
				{ id = "42", position = Vector3.new(1, 0, 0), kind = "driver", speed = 5 },
			}, off).spook).to.equal(false)

			-- AND THE SPEED FOLLOWS: the real driver runs it, the beater at the same distance does
			-- not. `settledSpeed` lets the ACCEL ramp finish, so these are the asked-for speeds.
			-- MEASURED WHILE HE IS STILL THERE, which is the whole claim: see `pushedSpeed`.
			local ran = pushedSpeed(on, close)
			expect(math.abs(ran - PACE.RUN_SPEED) < 0.5).to.equal(true)
			local pushed = pushedSpeed(on, close, true)
			expect(pushed <= PACE.TROT_SPEED + 0.5).to.equal(true)
			expect(pushed < ran).to.equal(true)
			TestKit.note(
				string.format(
					"boar-pace: a real driver %.0f studs off runs it at %.1f; the phantom beater at the same distance pushes it at %.1f",
					close,
					ran,
					pushed
				)
			)
		end)

		it("walks away from a beater, trots when it is crowded, and runs from a man", function()
			-- THE DEFECT KAREN FELT, as a number. `Brain:_step`'s flee branch asks for
			-- SPRINT_SPEED whenever anything is inside a flush radius, and the Forest Test's phantom
			-- beater is inside one by construction -- so every pushed herd crossed the road at 38
			-- studs/s, a real boar's 40 km/h. Karen: "they seems walking to fast".
			-- PHANTOM, because the rungs below are the beater's. Measured on this commit: a beater
			-- 14 studs off is walked at 4.5, one at 11 is trotted at 11, and the same two WITHOUT the
			-- mark are a real driver inside `DRIVER_RUN_STUDS` and run at 24 (task 123 round 5).
			-- 14 studs: inside the 15-stud flush, outside the 12 that lifts it to a trot.
			local walk, walkState = pushedSpeed(on, 14, true)
			expect(walkState).to.equal("FLEE")
			expect(math.abs(walk - PACE.WALK_SPEED) < 0.5).to.equal(true)
			-- ...and it is DRAWN walking too, which is the other half of "they seems walking to fast":
			-- the gait bands and the pace have to agree or the feet slide.
			expect((Boar.stepSoundFor(PACE.WALK_SPEED, CONFIG))).to.equal("walk")

			-- CROWDED: the beater inside `TROT_WITHIN_STUDS` lifts it to a trot, not to a bolt.
			local crowded = pushedSpeed(on, PACE.TROT_WITHIN_STUDS - 1, true)
			expect(math.abs(crowded - PACE.TROT_SPEED) < 0.5).to.equal(true)
			expect((Boar.stepSoundFor(PACE.TROT_SPEED, CONFIG))).to.equal("trot")

			-- SPOOKED: a hunter inside `SPOOK_STUDS` and it runs, whatever the push said.
			local spooked = settledSpeed(on, {
				{ id = "beater", position = Vector3.new(14, 0, 0), kind = "driver", speed = 5 },
				{ id = "hunter", position = Vector3.new(PACE.SPOOK_STUDS - 1, 0, 0), kind = "shooter", speed = 0 },
			})
			-- `PACE.RUN_SPEED` and not `SPRINT_SPEED` since round 4: Karen, *"when they fleet make
			-- speed slover it's to fast"*. 38 studs/s IS a real boar's 40 km/h and does not read as
			-- something a hunter can follow.
			expect(math.abs(spooked - PACE.RUN_SPEED) < 0.5).to.equal(true)

			-- WITH PACE OFF IT IS THE OLD WORLD, line for line: the same beater, SPRINT_SPEED.
			local old = settledSpeed(off, beaterFar)
			expect(math.abs(old - CONFIG.SPRINT_SPEED) < 0.5).to.equal(true)
			TestKit.note(
				string.format(
					"boar-pace: pushed %.1f, crowded %.1f, spooked %.1f studs/s -- against %.1f with PACE off",
					walk,
					crowded,
					spooked,
					old
				)
			)
		end)

		it("makes a shot run the herd, which is the existing bolt and not a second rule", function()
			-- A shot already sets `_boltFor` and kicks `_speed`; the pace clamp must not undo that,
			-- and `_boltFor > 0` is the first half of `spooked` for exactly this reason.
			local brain = Brain.new(on, FIELD, START, Random.new(7))
			local beater = { stimulus(14, "driver", 5) }
			drive(brain, math.ceil(1 / DT), function()
				return beater
			end, START)
			-- ...walking, because a beater is a push...
			local before = brain:step(DT, obs(START, beater)).targetVelocity.Magnitude
			expect(before < PACE.TROT_SPEED).to.equal(true)
			-- ...and then a bang, inside SHOT_AUDIBLE_STUDS.
			local intents = drive(
				brain,
				math.ceil(0.5 / DT),
				function()
					return beater
				end,
				START,
				function(step)
					return if step == 1
						then { sounds = { { kind = "shot", position = Vector3.new(0, 0, 60) } } }
						else nil
				end
			)
			local after = intents[#intents].intent.targetVelocity.Magnitude
			expect(after > PACE.TROT_SPEED).to.equal(true)
			-- `PACE.RUN_SPEED`, not the gait band: round 4 slowed a flight to 24 studs/s and the
			-- band that calls 24 a RUN is the playtest world's (`ForestTestBoot` sets
			-- `MODEL.RUN_FROM` to `(TROT_SPEED + RUN_SPEED) / 2`), not the module's 28. Asserting
			-- `stepSoundFor` against the MODULE config here would be asserting the wrong world.
			expect(math.abs(after - PACE.RUN_SPEED) < 1).to.equal(true)
			TestKit.note(string.format("boar-pace: a shot took the herd from %.1f to %.1f studs/s", before, after))
		end)
	end)

	-- ------------------------------------------------------------------ 1c. the march order
	describe("boar behaviour: a sounder marches sow, young, males (task 123)", function()
		-- KAREN, 2026-10-05: "always first go famale and then kids behind / male can walk together
		-- or on the end or alone". And Animal Diversity Web on Sus scrofa, verbatim: "When
		-- traveling, mothers keep their young in the middle, with adults in the lead and rear."
		--   https://animaldiversity.org/accounts/Sus_scrofa/
		-- Note: docs/research/2026-10-05-sounder-march-order.md
		local function row(id: string, kind: string?, key: number)
			return { id = id, kind = kind, key = key }
		end

		it("puts the females first, the cubs behind them and the males last", function()
			-- Deliberately handed in the WRONG order and with the males nearest the front, so the
			-- answer cannot come from the input order or from the distance alone.
			local order = Boar.marchOrder({
				row("male1", "male", 1),
				row("cub2", "cub", 50),
				row("sow", "female", 40),
				row("cub1", "cub", 20),
			}, CONFIG)
			expect(order[1]).to.equal("sow")
			expect(order[2]).to.equal("cub1")
			expect(order[3]).to.equal("cub2")
			expect(order[4]).to.equal("male1")
		end)

		it("orders within a kind by distance to the exit line, then by id", function()
			local order = Boar.marchOrder({
				row("b", "cub", 10),
				row("a", "cub", 10),
				row("far", "cub", 90),
			}, CONFIG)
			-- Same distance: the id breaks it, so the order is the same every time it is drawn.
			expect(order[1]).to.equal("a")
			expect(order[2]).to.equal("b")
			expect(order[3]).to.equal("far")
		end)

		it("sends the hindmost female BEHIND the cubs once there are two of them", function()
			-- ADW's stricter claim: adults in the lead AND rear, the young between them. Today's
			-- MAKEUP builds one sow and her young, so this is reachable by parameter only -- which
			-- is why it is a spec and not a thing nobody can see.
			local order = Boar.marchOrder({
				row("sow", "female", 10),
				row("aunt", "female", 20),
				row("cub1", "cub", 30),
				row("cub2", "cub", 40),
				row("male1", "male", 50),
			}, CONFIG)
			expect(order[1]).to.equal("sow")
			expect(order[2]).to.equal("cub1")
			expect(order[3]).to.equal("cub2")
			expect(order[4]).to.equal("aunt") -- the rear guard
			expect(order[5]).to.equal("male1")
			-- ...and one word of data turns it off again.
			local off = table.clone(CONFIG)
			local sounder = table.clone(CONFIG.SOUNDER)
			local makeup = table.clone(CONFIG.SOUNDER.MAKEUP)
			makeup.REAR_GUARD = false
			sounder.MAKEUP = makeup
			off.SOUNDER = sounder
			local plain = Boar.marchOrder({
				row("sow", "female", 10),
				row("aunt", "female", 20),
				row("cub1", "cub", 30),
			}, off)
			expect(plain[2]).to.equal("aunt")
		end)

		it("is exactly the old rule when every animal is the same kind", function()
			-- With `BOAR_MODEL` off `Boar.sounderKinds` gives every member the same kind, so the
			-- rank is uniform and this is the "nearest the exit line, tie-broken by id" rule the DEV
			-- drive has always used. That equality is what keeps the flag-OFF world unchanged.
			local kinds = Boar.sounderKinds(4, {}, CONFIG)
			local rows = {}
			for index, kind in ipairs(kinds) do
				table.insert(rows, row(string.format("b%d", index), kind, 100 - index * 10))
			end
			local order = Boar.marchOrder(rows, CONFIG)
			expect(order[1]).to.equal("b4") -- key 60, the nearest the exit
			expect(order[4]).to.equal("b1") -- key 90, the furthest
		end)
	end)

	-- ------------------------------------------------------------------ 1d. trunks and turning
	describe("boar behaviour: round the trunk, and no mouse turning (task 123)", function()
		local on = paceConfig(true)
		local off = paceConfig(false)
		local PACE = CONFIG.PACE
		local NORTH = Vector3.new(0, 0, 1)

		local function degreesBetween(a: Vector3, b: Vector3): number
			return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
		end

		it("turns toward the side that is CLEAR, and only nudges off a flank", function()
			-- WHICH WAY IS RIGHT, derived rather than assumed (task 129: this case had it mirrored
			-- and said so for six tasks, because no gate could reach it). Facing NORTH = (0, 0, 1),
			-- Roblox's `RightVector` is (-1, 0, 0): the basis is `X = Y x Z` with `Z = -LookVector`,
			-- so cross((0,1,0), (0,0,-1)) = (-1, 0, 0). **Right is -X when you face +Z.** The whisker
			-- agrees with that by construction -- `Runtime` casts `right` at `turnFlat(nose, +sweep)`
			-- and `steerAroundTrunk` rotates by `+turn` to escape something on the left, and
			-- `turnFlat(NORTH, +a).X = -sin(a)`. Measured on this commit: X = -0.819 at the 55-degree
			-- turn.
			local right = Brain.steerAroundTrunk(NORTH, { ahead = true, left = true, right = false }, on, 1)
			expect(right.X < 0).to.equal(true)
			expect(math.abs(degreesBetween(right, NORTH) - PACE.WHISKER_TURN_DEG) < 0.01).to.equal(true)
			-- ...and the mirror, which is the half that a RANDOM sign could not promise.
			local left = Brain.steerAroundTrunk(NORTH, { ahead = true, left = false, right = true }, on, 1)
			expect(left.X > 0).to.equal(true)

			-- A FLANK TOUCH ALONE IS HALF THE ANGLE: brushing past a trunk is a lean, not a swerve.
			local nudge = Brain.steerAroundTrunk(NORTH, { ahead = false, left = true, right = false }, on, 1)
			expect(math.abs(degreesBetween(nudge, NORTH) - PACE.WHISKER_TURN_DEG / 2) < 0.01).to.equal(true)

			-- BOXED IN: both flanks and ahead. Twice the angle, the animal's OWN way -- and the two
			-- animals go opposite ways, which a shared coin flip could not give either.
			local boxedA = Brain.steerAroundTrunk(NORTH, { ahead = true, left = true, right = true }, on, 1)
			local boxedB = Brain.steerAroundTrunk(NORTH, { ahead = true, left = true, right = true }, on, -1)
			expect(boxedA.X < 0).to.equal(true) -- prefer +1 is the animal's RIGHT, which is -X
			expect(boxedB.X > 0).to.equal(true)

			-- Nothing in the way, and nothing to decide.
			expect(Brain.steerAroundTrunk(NORTH, { ahead = false, left = false, right = false }, on, 1)).to.equal(NORTH)
			-- ...and with PACE off the whiskers are not consulted at all.
			expect(Brain.steerAroundTrunk(NORTH, { ahead = true, left = true, right = false }, off, 1)).to.equal(NORTH)
		end)

		it("caps a WALKING animal's turn at PACE.WALK_TURN_DEG, and lets a running one swerve", function()
			-- MEASURED BEFORE THIS TASK, in Karen's own place over 106 s of crossings: a walking
			-- boar's facing changed by up to 688 deg/s. `Boar.CONFIG.TURN_RATE` is one number for
			-- every gait -- 4 rad/s = 229 deg/s -- so there was no walking turn rate to exceed.
			--
			-- Driven here with the stimulus BEHIND the animal, so the flee direction is a full
			-- 180 degrees from where it is facing and the cap is the only thing deciding the rate.
			local function turnRate(config): number
				local brain = Brain.new(config, FIELD, START, Random.new(3))
				-- Hand it a threat right on top of it so it flushes at once, then let the ACCEL ramp
				-- reach the speed we are measuring the turn at.
				-- THE BEATER'S MARK AND THE BEATER'S DISTANCE (task 129). A threat 6 studs off with no
				-- mark is a real driver inside `DRIVER_RUN_STUDS` and the animal RUNS (measured: 24),
				-- so the walking cap was being asked about a running animal. 14 studs is the rung
				-- that walks -- measured 4.5 studs/s on this commit, which is `PACE.WALK_SPEED`.
				local threats = { stimulus(14, "driver", 0, true) } -- the walking rung: see `pushedSpeed`
				drive(brain, math.ceil(2 / DT), function()
					return threats
				end, START)
				local worst = 0
				local before = nil
				for _ = 1, math.ceil(1 / DT) do
					local intent = brain:step(DT, obs(START, threats))
					local facing = intent.facing
					if before ~= nil and facing.Magnitude > 1e-6 then
						worst = math.max(worst, degreesBetween(before, facing) / DT)
					end
					before = facing
				end
				return worst
			end

			-- A pushed animal is WALKING (`PACE.WALK_SPEED` is inside the walk band), so the walking
			-- cap is the one that binds, and it binds with a frame of float slack.
			local walking = turnRate(on)
			expect(walking <= PACE.WALK_TURN_DEG + 1).to.equal(true)
			-- ...and with PACE off the same animal may turn at the one global rate, which is nearly
			-- three times as fast. This is the A/B, and it is why the complaint was a number.
			local loose = turnRate(off)
			expect(math.deg(CONFIG.TURN_RATE) > PACE.WALK_TURN_DEG * 2).to.equal(true)
			expect(loose > walking).to.equal(true)
			TestKit.note(
				string.format(
					"boar-pace: a walking turn is capped at %.0f deg/s (measured %.0f) against %.0f with PACE off",
					PACE.WALK_TURN_DEG,
					walking,
					loose
				)
			)
		end)

		it("runs every animal that HEARS a shot, not only the one that was hit", function()
			-- KAREN: "after shoot all run away". The radius is `SENSE.SHOT_AUDIBLE_STUDS` = 350, and
			-- `Runtime:hearShot` hands the sound to every live boar, so the radius IS the rule.
			expect(SENSE.SHOT_AUDIBLE_STUDS).to.equal(350)
			local brain = Brain.new(on, FIELD, START, Random.new(3))
			for _ = 1, 30 do
				brain:step(DT, obs(START, {}))
			end
			expect(brain:state()).to.equal("IDLE")
			-- A bang 200 studs away, which no threat radius in the game would have noticed.
			expect(brain:spook(Vector3.new(0, 0, 200))).to.equal(true)
			expect(brain:state()).to.equal("FLEE")
			local intents = drive(brain, math.ceil(0.5 / DT), function()
				return {}
			end, START)
			local speed = intents[#intents].intent.targetVelocity.Magnitude
			expect(math.abs(speed - PACE.RUN_SPEED) < 1).to.equal(true)
			-- ...and a carcass is past being frightened.
			TestKit.note(string.format("boar-pace: a bang 200 studs off put a calm boar at %.1f studs/s", speed))
		end)
	end)

	-- ------------------------------------------------------------------ 2. perceive
	describe("boar behaviour: Brain.perceive is the one function, and it is pure", function()
		local on = configWith(true)

		local function reactionAt(distance: number, kind: string?, speed: number?): string
			return Brain.perceive(START, { stimulus(distance, kind, speed) }, on).reaction
		end

		it("answers the bands Karen gave, standing and moving", function()
			-- STANDING: noticed at 25, bolts at 15. The 26 and 24 pair is the whole of "a boar
			-- notices a standing person at ~25 studs" and it fails if either number moves.
			expect(reactionAt(26)).to.equal("none")
			expect(reactionAt(24)).to.equal("alert")
			expect(reactionAt(14)).to.equal("flee")
			-- MOVING: noticed at 60, bolts at DETECT_RADIUS = 40. `speed = 5` is over
			-- MOVING_SPEED = 2 and under a walk, which is what "once move" means.
			expect(reactionAt(61, "driver", 5)).to.equal("none")
			expect(reactionAt(59, "driver", 5)).to.equal("avoid")
			expect(reactionAt(39, "driver", 5)).to.equal("flee")
			-- ...and the same person STANDING at 59 is nothing at all, which is the pair that makes
			-- the speed term the thing under test rather than the distance.
			expect(reactionAt(59, "driver", 0)).to.equal("none")
		end)

		it("gives a dog half again the radii, and counts it as moving even when it is not", function()
			-- HOOK ONLY (the brief puts dogs out of scope): nothing produces `kind = "dog"` yet, and
			-- the first dog task fills it in and touches nothing else. 80 studs is past a person's
			-- 60 and inside a dog's 90; 55 is past a person's 40 and inside a dog's 60.
			expect(reactionAt(80, "dog", 10)).to.equal("avoid")
			expect(reactionAt(91, "dog", 10)).to.equal("none")
			expect(reactionAt(55, "dog", 10)).to.equal("flee")
			expect(reactionAt(80, "dog", 0)).to.equal("avoid") -- standing, still "moving"
		end)

		it("takes the STRONGEST reaction, not the nearest stimulus", function()
			-- The far one is moving at 39 (inside DETECT_RADIUS) and would flush the animal; the near
			-- one is standing at 20 and would only lift its head. Flee wins, and the CAUSE is the
			-- one that flushed it -- which is what the route then runs away from.
			local perception = Brain.perceive(START, {
				{ id = "near", position = Vector3.new(20, 0, 0), kind = "shooter", speed = 0 },
				{ id = "far", position = Vector3.new(39, 0, 0), kind = "driver", speed = 5 },
			}, on)
			expect(perception.reaction).to.equal("flee")
			expect(perception.cause.id).to.equal("far")
			-- ...and the NEAREST is still reported, because the calm test and the old centroid both
			-- rest on it.
			expect(math.abs(perception.nearestDistance - 20) < EPSILON).to.equal(true)
		end)

		it("reports the centroid of what is flushing it, and nil when there is nothing", function()
			local empty = Brain.perceive(START, {}, on)
			expect(empty.reaction).to.equal("none")
			expect(empty.centroid).to.equal(nil)
			expect(empty.nearestDistance).to.equal(math.huge)
			expect(empty.calm).to.equal(true)
			-- Two inside the flush band: the centroid is between them, which is the anchor the route
			-- is pushed sideways from.
			local two = Brain.perceive(START, {
				{ id = "a", position = Vector3.new(10, 0, 0), kind = "driver", speed = 0 },
				{ id = "b", position = Vector3.new(0, 0, 10), kind = "driver", speed = 0 },
			}, on)
			expect(two.reaction).to.equal("flee")
			expect(flatDistance(two.centroid, Vector3.new(5, 0, 5)) < EPSILON).to.equal(true)
		end)

		it("keeps CALM_RADIUS - DETECT_RADIUS == SENSE.CALM_MARGIN, so the OFF branch cannot drift", function()
			-- The calm test is per stimulus now (section 4.3). It is arithmetically today's only
			-- while this equality holds, and this is the one assertion standing between the two.
			expect(CONFIG.CALM_RADIUS - CONFIG.DETECT_RADIUS).to.equal(SENSE.CALM_MARGIN)
			-- ...and both branches agree at the boundary for a standing driver, which is what the
			-- equality is FOR: off, the hysteresis is 70; on, it is 25 + 30 = 55 for a standing
			-- person and 40 + 30 = 70 for a moving one.
			-- OFF: the hysteresis is one radius for everything, CALM_RADIUS = 70.
			expect(Brain.perceive(START, { stimulus(70.5, "driver") }, configWith(false)).calm).to.equal(true)
			expect(Brain.perceive(START, { stimulus(69.5, "driver") }, configWith(false)).calm).to.equal(false)
			-- ON: it is the stimulus's own NOTICE radius plus the margin, so a MOVING man is
			-- NOTICE_MOVING + CALM_MARGIN = 60 + 30 and a standing one NOTICE_STANDING + CALM_MARGIN
			-- = 25 + 30. The margin is added to the NOTICE radius and never to the flush radius,
			-- which is what makes the OFF branch (one radius for both) come out at today's 70. The pair at 89.5 / 90.5 is the moving boundary, and the
			-- pair at 54.5 / 55.5 is the standing one -- the same stimulus, two different bands,
			-- which is what "per stimulus" means and what one global radius could not express.
			expect(Brain.perceive(START, { stimulus(89.5, "driver", 5) }, on).calm).to.equal(false)
			expect(Brain.perceive(START, { stimulus(90.5, "driver", 5) }, on).calm).to.equal(true)
			expect(Brain.perceive(START, { stimulus(54.5, "driver") }, on).calm).to.equal(false)
			expect(Brain.perceive(START, { stimulus(55.5, "driver") }, on).calm).to.equal(true)
		end)
	end)

	-- ------------------------------------------------------------------ 3-5. ALERT
	describe("boar behaviour: ALERT is head up, stopped, turned to the cause", function()
		local on = configWith(true)

		it("enters within 0.25 s of a standing man at 24 studs and faces him", function()
			local brain = Brain.new(on, FIELD, START, Random.new(3))
			local man = { stimulus(24, "shooter") }
			local elapsed = 0
			while brain:state() ~= "ALERT" and elapsed < 1 do
				brain:step(DT, obs(START, man))
				elapsed += DT
			end
			expect(brain:state()).to.equal("ALERT")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)

			-- THE FACING REACHES HIM, and never faster than the existing TURN_RATE: a 180-degree
			-- turn takes 0.79 s, so 1.0 s is the budget and the per-step bound is what makes it a
			-- turn rather than a snap.
			local toward = Vector3.new(1, 0, 0)
			local previous = nil
			local aligned, waited = false, 0
			local fastest = 0
			while waited < 1.0 do
				local intent = brain:step(DT, obs(START, man))
				local facing = Vector3.new(intent.facing.X, 0, intent.facing.Z).Unit
				if previous then
					local turned =
						math.abs(math.atan2(previous.X * facing.Z - previous.Z * facing.X, previous:Dot(facing)))
					fastest = math.max(fastest, turned / DT)
				end
				previous = facing
				if math.deg(math.acos(math.clamp(facing:Dot(toward), -1, 1))) <= 10 then
					aligned = true
					break
				end
				waited += DT
			end
			expect(aligned).to.equal(true)
			expect(fastest <= CONFIG.TURN_RATE + EPSILON).to.equal(true)
			TestKit.note(
				string.format("boar-behaviour: ALERT faced the cause in %.2f s, fastest %.2f rad/s", waited, fastest)
			)
		end)

		it("stops: the setpoint goes to zero and never leaves it, and it asks for no route", function()
			local brain = Brain.new(on, FIELD, START, Random.new(4))
			local man = { stimulus(24, "shooter") }
			-- The animal may have been wandering when it noticed him, so the ACCEL ramp has up to
			-- WANDER_SPEED / ACCEL = 0.07 s of slowing down to do. After that it is stopped, and it
			-- never moves again while it is alert.
			local fastest = 0
			for step = 1, math.ceil(SENSE.ALERT_SECONDS / DT) - 2 do
				local intent = brain:step(DT, obs(START, man))
				expect(intent.pathRequest).to.equal(nil)
				if step * DT > 0.2 then
					expect(intent.state).to.equal("ALERT")
					fastest = math.max(fastest, intent.targetVelocity.Magnitude)
				end
			end
			expect(fastest < EPSILON).to.equal(true)
		end)

		it("settles after ALERT_SECONDS, puts its home where it stands, and will not look again", function()
			local brain = Brain.new(on, FIELD, START, Random.new(5))
			local where = Vector3.new(0, 0, 7)
			local man = { stimulus(24, "shooter") }
			local held = 0
			while brain:state() ~= "ALERT" do
				brain:step(DT, obs(where, man))
			end
			while brain:state() == "ALERT" and held < SENSE.ALERT_SECONDS * 2 do
				brain:step(DT, obs(where, man))
				held += DT
			end
			expect(brain:state()).to.equal("IDLE")
			expect(held >= SENSE.ALERT_SECONDS - DT * 2).to.equal(true)
			expect(flatDistance(brain:debug().home, where) < EPSILON).to.equal(true)

			-- THE REFRACTORY. He is still standing there, and the animal grazes instead of
			-- flip-flopping IDLE<->ALERT every 2.5 s for ever.
			local waited = 0
			while waited < SENSE.ALERT_REFRACTORY_SECONDS - 0.5 do
				brain:step(DT, obs(where, man))
				expect(brain:state()).to.equal("IDLE")
				waited += DT
			end
			-- ...and then it does look again, which is the half that makes it a refractory period
			-- and not a one-shot.
			local again = 0
			while brain:state() ~= "ALERT" and again < 2 do
				brain:step(DT, obs(where, man))
				again += DT
			end
			expect(brain:state()).to.equal("ALERT")
			TestKit.note(string.format("boar-behaviour: head up %.2f s, then %.2f s of grazing", held, waited + again))
		end)

		it("runs instead when the man closes to 14 studs", function()
			local brain = Brain.new(on, FIELD, START, Random.new(6))
			while brain:state() ~= "ALERT" do
				brain:step(DT, obs(START, { stimulus(24, "shooter") }))
			end
			local elapsed = 0
			while brain:state() ~= "FLEE" and elapsed < 1 do
				brain:step(DT, obs(START, { stimulus(14, "shooter") }))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
		end)

		it("turns away instead when the man starts moving and is outside the flush band", function()
			-- DESIGN SECTION 12 CASE 5 SAYS "at 30 studs", WHICH ITS OWN SECTION 4.2 CONTRADICTS: a
			-- MOVING person's flush radius is DETECT_RADIUS = 40, so a man moving at 30 studs
			-- flushes the animal rather than making it turn away. The band where "it moved" means
			-- AVOID is 40 to 60, so this drives 45 -- a man who has stood up and walked off to one
			-- side, which is the behaviour the state exists for.
			local brain = Brain.new(on, FIELD, START, Random.new(7))
			while brain:state() ~= "ALERT" do
				brain:step(DT, obs(START, { stimulus(24, "shooter") }))
			end
			local elapsed = 0
			while brain:state() ~= "AVOID" and elapsed < 1 do
				brain:step(DT, obs(START, { stimulus(45, "shooter", 5) }))
				elapsed += DT
			end
			expect(brain:state()).to.equal("AVOID")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
		end)
	end)

	-- ------------------------------------------------------------------ 6. AVOID
	describe("boar behaviour: AVOID turns away and trots off, and costs no routes", function()
		local on = configWith(true)

		local function intoAvoid(seed: number)
			local brain = Brain.new(on, FIELD, START, Random.new(seed))
			local man = { stimulus(45, "shooter", 5) }
			while brain:state() ~= "AVOID" do
				brain:step(DT, obs(START, man))
			end
			return brain
		end

		it("heads at least 90 degrees off the cause within a second, and keeps opening the gap", function()
			local brain = intoAvoid(11)
			local cause = Vector3.new(45, 0, 0)
			local man = function()
				return { { id = "s", position = cause, kind = "shooter", speed = 5 } }
			end
			local intents, finished = drive(brain, math.ceil(3 / DT), man, START)

			-- A REFUSAL, NOT A SIDESTEP (section 7.1): `AVOID_TURN_DEG` is 120, measured off the line
			-- TOWARD the man, so inside a second the direction of travel is at least 90 degrees off
			-- him and the radial component is negative. The turn itself costs 120 deg / TURN_RATE =
			-- 0.52 s, which is why the window is a second and not a tick.
			local widest, at = 0, 0
			for index, row in ipairs(intents) do
				local v = row.intent.targetVelocity
				if v.Magnitude > 1 then
					local heading = Vector3.new(v.X, 0, v.Z).Unit
					local toward = Vector3.new(cause.X - row.position.X, 0, cause.Z - row.position.Z).Unit
					local off = math.deg(math.acos(math.clamp(heading:Dot(toward), -1, 1)))
					if index * DT <= 1.0 and off > widest then
						widest, at = off, index * DT
					end
				end
			end
			expect(widest >= 90).to.equal(true)

			-- ...and it is LEAVING. The window is THREE seconds and not section 12 case 6's two: the
			-- first half-second is spent turning away from the man the animal was facing while it
			-- was alert, and during it the distance shrinks. Measured below, both ways.
			local twoSeconds = flatDistance(intents[math.ceil(2 / DT)].position, cause) - 45
			local opened = flatDistance(finished, cause) - 45
			expect(opened >= 20).to.equal(true)
			TestKit.note(
				string.format(
					"boar-behaviour: AVOID turned %.0f deg off the cause by %.2f s, opened %.1f studs in 2 s and %.1f in 3 s",
					widest,
					at,
					twoSeconds,
					opened
				)
			)
		end)

		it("converges on TROT_SPEED through the existing ACCEL ramp, and asks for no path at all", function()
			local brain = intoAvoid(12)
			local man = function()
				return { stimulus(45, "shooter", 5) }
			end
			-- `previous` STARTS FROM A REAL STEP, not from zero: the animal is already moving when
			-- this case picks it up (entering AVOID costs a step), so a zero start would read the
			-- whole of that step's speed as one frame's acceleration and fail on arithmetic.
			local previous = brain:step(DT, obs(START, man())).targetVelocity.Magnitude
			local fastestRise = 0
			local requests = 0
			local final = 0
			for _ = 1, 600 do
				local intent = brain:step(DT, obs(START, man()))
				if intent.pathRequest ~= nil then
					requests += 1
				end
				local speed = intent.targetVelocity.Magnitude
				fastestRise = math.max(fastestRise, (speed - previous) / DT)
				previous = speed
				final = speed
			end
			-- NO ROUTE, EVER, FROM AVOID. `ComputeAsync` is this system's one expensive call and a
			-- behaviour task may not change the path budget (section 4.4).
			expect(requests).to.equal(0)
			expect(fastestRise <= CONFIG.ACCEL + EPSILON).to.equal(true)
			expect(math.abs(final - CONFIG.TROT_SPEED) < EPSILON).to.equal(true)
		end)

		it("settles AVOID_SECONDS after the last tick anything was noticed", function()
			local brain = intoAvoid(13)
			-- He is still in the notice band: the clock keeps being pushed back and the animal keeps
			-- leaving, which is what "since the last tick any stimulus was noticed" means.
			local held = 0
			while held < SENSE.AVOID_SECONDS * 2 do
				brain:step(DT, obs(START, { stimulus(45, "shooter", 5) }))
				expect(brain:state()).to.equal("AVOID")
				held += DT
			end
			-- Gone: it settles, and not before the four seconds are up.
			local waited = 0
			while brain:state() == "AVOID" and waited < SENSE.AVOID_SECONDS * 3 do
				brain:step(DT, obs(START, {}))
				waited += DT
			end
			expect(brain:state()).to.equal("IDLE")
			expect(waited >= SENSE.AVOID_SECONDS - DT * 2).to.equal(true)
		end)

		it("counts as escaping when it crosses the line, exactly once", function()
			-- AVOID joins FLEE and WOUNDED in `_outcome` (section 3.4): the line is the line, and how
			-- the animal got over it does not change that it is over it. An IDLE boar wandering over
			-- the same line still does NOT escape, which is the pair that makes this a rule.
			local brain = intoAvoid(14)
			local over = Vector3.new(0, 0, FIELD.exitZ - 1)
			local first = brain:step(DT, obs(over, { stimulus(45, "shooter", 5) }))
			expect(first.despawn).to.equal(true)
			expect(first.reason).to.equal("escaped")
			local second = brain:step(DT, obs(over, {}))
			expect(second.despawn).to.equal(false)

			local idle = Brain.new(on, FIELD, START, Random.new(15))
			local wandered = idle:step(DT, obs(over, {}))
			expect(wandered.despawn).to.equal(false)
			expect(idle:state()).to.equal("IDLE")
		end)
	end)

	-- ------------------------------------------------------------------ 7-9. a shot, and precedence
	describe("boar behaviour: a shot is a sound", function()
		local on = configWith(true)

		local function shotAt(distance: number)
			return { { kind = "shot", position = Vector3.new(distance, 0, 0) } }
		end

		it("sprints on the same tick inside SHOT_AUDIBLE_STUDS, and holds it for SHOT_SPRINT_SECONDS", function()
			local brain = Brain.new(on, FIELD, START, Random.new(21))
			local intent = brain:step(DT, obs(START, {}, { sounds = shotAt(340) }))
			expect(intent.state).to.equal("FLEE")
			-- The bolt kick is the existing one-off ACCEL bypass, so the setpoint on this very tick
			-- is SPRINT_SPEED * BOLT_KICK less the one ramp step that follows it.
			local kick = CONFIG.SPRINT_SPEED * CONFIG.WOUND.BOLT_KICK
			expect(intent.targetVelocity.Magnitude >= kick - CONFIG.ACCEL * DT - EPSILON).to.equal(true)

			-- ...and it is still sprinting most of the way through the four seconds, then stops
			-- being told to by the bolt. With nothing in range it calms down on the existing timer.
			local sprinting = 0
			for _ = 1, math.ceil((SENSE.SHOT_SPRINT_SECONDS - 0.2) / DT) do
				local next_ = brain:step(DT, obs(START, {}))
				if next_.targetVelocity.Magnitude >= CONFIG.SPRINT_SPEED - 1 then
					sprinting += DT
				end
			end
			expect(sprinting >= SENSE.SHOT_SPRINT_SECONDS - 0.5).to.equal(true)
			TestKit.note(string.format("boar-behaviour: a heard shot held the sprint %.2f s", sprinting))
		end)

		it("hears nothing past SHOT_AUDIBLE_STUDS, and nothing at all with the flag off", function()
			local deaf = Brain.new(on, FIELD, START, Random.new(22))
			for _ = 1, 120 do
				deaf:step(DT, obs(START, {}, { sounds = shotAt(360) }))
			end
			expect(deaf:state()).to.equal("IDLE")

			-- WITH THE FLAG OFF A BOAR DOES NOT HEAR AT ALL. `MatchBoot` wires `Weapon.ShotFired`
			-- unconditionally, so this one test is what keeps the live game's boar exactly what it
			-- was: before task 118 there was no server-side "a shot was fired" fact anywhere.
			local off = Brain.new(configWith(false), FIELD, START, Random.new(22))
			for _ = 1, 120 do
				off:step(DT, obs(START, {}, { sounds = shotAt(10) }))
			end
			expect(off:state()).to.equal("IDLE")
		end)

		it("routes away from the shot, not toward wherever it was going", function()
			-- While bolting, the shot point IS the threat -- the existing rule (hit-zones section
			-- 6.2 item 5), reused with no new code. The route is pushed sideways AWAY from it, so a
			-- shot from +X sends the animal's target to -X.
			local brain = Brain.new(on, FIELD, START, Random.new(23))
			local request = nil
			for _ = 1, 60 do
				local intent = brain:step(DT, obs(START, {}, { sounds = if request then nil else shotAt(200) }))
				request = request or intent.pathRequest
			end
			expect(request).to.be.ok()
			expect(request.X < 0).to.equal(true)
		end)

		it("is ignored by a carcass, a crippled animal and a terminal one", function()
			local down = Brain.new(on, FIELD, START, Random.new(24))
			down:step(DT, obs(START, {}, { wound = { collapse = true } }))
			expect(down:state()).to.equal("DOWN")
			local still = down:step(DT, obs(START, {}, { sounds = shotAt(10) }))
			expect(still.state).to.equal("DOWN")
			expect(still.targetVelocity.Magnitude).to.equal(0)

			-- A CRIPPLED BOAR'S BACK END IS GONE AND A BANG DOES NOT GIVE IT BACK: it keeps
			-- circling at CRIPPLE_SPEED, which is the number a bolt would destroy.
			local crippled = Brain.new(on, FIELD, START, Random.new(25))
			crippled:step(
				DT,
				obs(START, {}, {
					hitEvents = { { severity = "mortal", class = "crippling", from = Vector3.new(0, 0, 20) } },
				})
			)
			expect(crippled:state()).to.equal("CRIPPLED")
			for _ = 1, 30 do
				local intent = crippled:step(DT, obs(START, {}, { sounds = shotAt(5) }))
				expect(intent.state).to.equal("CRIPPLED")
				expect(intent.targetVelocity.Magnitude <= CONFIG.WOUND.CRIPPLE_SPEED + EPSILON).to.equal(true)
			end
		end)

		it("never returns a WOUNDED animal to a calm state, shot or no shot", function()
			local brain = Brain.new(on, FIELD, START, Random.new(26))
			brain:step(DT, obs(START, {}, { hitEvents = { { severity = "mortal", class = "vital" } } }))
			expect(brain:state()).to.equal("WOUNDED")
			brain:step(DT, obs(START, {}, { sounds = shotAt(50) }))
			for _ = 1, math.ceil((CONFIG.CALM_TIME + SENSE.SHOT_SPRINT_SECONDS + 4) / DT) do
				brain:step(DT, obs(START, {}))
			end
			expect(brain:state()).to.equal("WOUNDED")
		end)

		it("lets a HIT beat every perception on the tick it lands", function()
			-- Precedence row 3 is above every sense row, and it has to be: a reaction that waited for
			-- the next sense tick would be up to SENSE_INTERVAL late, and late is indistinguishable
			-- from nothing having happened. A standing man at 24 would make this animal ALERT.
			local brain = Brain.new(on, FIELD, START, Random.new(27))
			local intent = brain:step(
				DT,
				obs(START, { stimulus(24, "shooter") }, { hitEvents = { { severity = "light", class = "body" } } })
			)
			expect(intent.state).to.equal("FLEE")
			expect(brain:state()).to.equal("FLEE")
		end)
	end)

	-- ------------------------------------------------------------------ 10. the alarm
	describe("boar behaviour: panic reaches a member through the sounder's alarm", function()
		local on = configWith(true)

		it("moves an IDLE member to FLEE within one sense tick", function()
			local brain = Brain.new(on, FIELD, START, Random.new(31))
			local alarmed = follower({ alarm = true })
			local elapsed = 0
			while brain:state() ~= "FLEE" and elapsed < 1 do
				brain:step(DT, obs(START, {}, { sounder = alarmed }))
				elapsed += DT
			end
			expect(brain:state()).to.equal("FLEE")
			expect(elapsed <= DESIGN_REACTION).to.equal(true)
		end)

		it("and the LEADER'S STATE alone no longer does, because that is the rule it replaces", function()
			-- TWO CORRECT RULES DISAGREEING IS THIS PROJECT'S NAMED KILLER. With the flag on, panic
			-- travels one way only: the Runtime's alarm, member to member with a delay. A leader
			-- that is running is not by itself a reason for a member 200 studs away to run.
			local brain = Brain.new(on, FIELD, START, Random.new(32))
			local running = follower({ leaderState = "FLEE" })
			for _ = 1, 600 do
				brain:step(DT, obs(START, {}, { sounder = running }))
			end
			expect(brain:state()).to.equal("IDLE")
		end)

		it("lets a member settle behind an ALERT leader, which the old rule could not", function()
			-- `leaderCalm` used to be `leaderState == "IDLE"`, so a leader with its head up would
			-- have pinned its whole sounder in FLEE for ever. It reads `Brain.classOf` now, and
			-- ALERT is calm.
			local brain = Brain.new(on, FIELD, START, Random.new(33))
			local alarmed = follower({ alarm = true })
			while brain:state() ~= "FLEE" do
				brain:step(DT, obs(START, {}, { sounder = alarmed }))
			end
			local settled = follower({ alarm = false, leaderState = "ALERT" })
			local waited = 0
			while brain:state() == "FLEE" and waited < CONFIG.CALM_TIME * 3 do
				brain:step(DT, obs(START, {}, { sounder = settled }))
				waited += DT
			end
			expect(brain:state()).to.equal("IDLE")
			expect(waited >= CONFIG.CALM_TIME).to.equal(true)
			-- ...and a PANICKED leader still holds it, so the class table is doing the work and not
			-- the timer alone.
			local pinned = Brain.new(on, FIELD, START, Random.new(34))
			while pinned:state() ~= "FLEE" do
				pinned:step(DT, obs(START, {}, { sounder = alarmed }))
			end
			for _ = 1, math.ceil(CONFIG.CALM_TIME * 3 / DT) do
				pinned:step(DT, obs(START, {}, { sounder = follower({ leaderState = "WOUNDED" }) }))
			end
			expect(pinned:state()).to.equal("FLEE")
		end)

		it("releases the alarm, so a sounder that panicked settles instead of running off the map", function()
			-- REVIEW ROUND 2, FINDING 1, and it is the case that was missing rather than a case that
			-- was wrong: every alarm assertion in this file hand-writes `follower({ alarm = ... })`,
			-- and the defect was that the RUNTIME never stopped publishing `alarm = true`. Row 8
			-- flushes an alarmed member and `_flush` resets `_sinceCalm`, so an alarmed member could
			-- never go calm, so the "every member is calm again" clear was unreachable: a sounder
			-- that panicked once ran until its last member crossed the exit line.
			--
			-- IT IS DRIVEN THROUGH A REAL RUNTIME, STEPPED BY HAND. There is no Heartbeat and
			-- therefore no physics: nothing moves, so nobody can escape, nothing is timed against a
			-- wall clock, and the only thing that can end the panic is the rule under test. The
			-- bodies are real Instances, which is why this case owns a folder and destroys it.
			local holder = Instance.new("Folder")
			holder.Name = "BoarBehaviourAlarmProbe"
			holder.Parent = workspace
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "AlarmProbe",
				rng = Random.new(118),
				config = { SENSE = { ENABLED = true } },
				threats = function()
					return {} -- nothing, ever: the panic has to end on its own or not at all
				end,
				requestPath = function(_agentId, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			local handles = runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 3)
			expect(#handles).to.equal(3)

			local function running(): number
				local n = 0
				for _, handle in ipairs(handles) do
					if Brain.classOf(handle.state()) == "panicked" then
						n += 1
					end
				end
				return n
			end

			runtime:step(DT)
			expect(running()).to.equal(0)
			-- ONE NON-LETHAL HIT on one member, which is the only outbreak this case needs.
			runtime:takeHit(handles[1].part, { zone = "body", ammo = "Buck", pellets = 1, at = 0 })

			local spread, spreadFor = false, 0
			for step = 1, math.ceil((SENSE.PANIC_DELAY_MAX + CONFIG.SENSE_INTERVAL + 0.5) / DT) do
				runtime:step(DT)
				if running() == #handles then
					spread, spreadFor = true, step * DT
					break
				end
			end
			expect(spread).to.equal(true)
			expect(runtime:stats().alarms >= 1).to.equal(true)

			-- ...AND NOW IT ENDS. Nothing is in range and nothing ever will be, so every member is
			-- back to IDLE. The budget is the hit boar's own bolt (`WOUND.BOLT_SECONDS`) plus
			-- `CALM_TIME` plus a sense tick, doubled: what is asserted is that it happens AT ALL,
			-- because with the latch it never did however long the spec waited.
			local budget = CONFIG.WOUND.BOLT_SECONDS + CONFIG.CALM_TIME + CONFIG.SENSE_INTERVAL
			local settled, settledFor = false, 0
			for step = 1, math.ceil(budget * 2 / DT) do
				runtime:step(DT)
				if running() == 0 then
					settled, settledFor = true, step * DT
					break
				end
			end
			expect(settled).to.equal(true)
			for _, handle in ipairs(handles) do
				expect(handle.state()).to.equal("IDLE")
			end
			TestKit.note(
				string.format(
					"boar-behaviour: a sounder of 3 was all running %.2f s after one hit and all IDLE again %.2f s later (budget %.1f s)",
					spreadFor,
					settledFor,
					budget * 2
				)
			)

			runtime:destroy()
			holder:Destroy()
		end)

		it("classifies every state the system has, and nothing else", function()
			-- One table, read by the alarm, by the herd's calm-down and by the Runtime's stats, so a
			-- ninth state cannot be forgotten in one predicate. The list is written out here on
			-- purpose: a state added to CLASS without a decision about its class fails this.
			local expected = {
				IDLE = "calm",
				ALERT = "calm",
				AVOID = "disturbed",
				FLEE = "panicked",
				WOUNDED = "panicked",
				CRIPPLED = "down",
				DOWN = "down",
				GONE = "gone",
			}
			local count = 0
			for state, class in pairs(Brain.CLASS) do
				expect(expected[state]).to.equal(class)
				count += 1
			end
			expect(count).to.equal(8)
			expect(Brain.classOf("IDLE")).to.equal("calm")
			expect(Brain.classOf(nil)).to.equal("gone")
		end)
	end)

	-- ------------------------------------------------------------------ the sounder's shape
	describe("boar behaviour: a sounder runs in single file or as a loose group", function()
		local on = configWith(true)

		it("steers a column member dead astern and a wedge member out to the side", function()
			-- Karen: "they usually do one line each after another or mixed like in real life". The
			-- formation is drawn ONCE per sounder by the Runtime and reaches the Brain as a plain
			-- value on the observation it already gets; this is the one expression that reads it.
			--
			-- INTEGRATED FOR A SECOND, not compared one step at a time, for the reason
			-- `boar_sounder.spec`'s own column case gives: `facing` is slewed by at most
			-- TURN_RATE * dt, so after one step two brains that want opposite things still look
			-- almost identical. Slot 3 stands +7 studs to the leader's RIGHT in the wedge and dead
			-- astern in the column, so where they have GOT TO is the difference the formation makes.
			local leaderAt = Vector3.new(0, 0, -40)
			local leader = {
				position = leaderAt,
				velocity = Vector3.new(0, 0, -CONFIG.TROT_SPEED),
				facing = Vector3.new(0, 0, -1),
				speed = CONFIG.TROT_SPEED,
			}

			local function run(formation: string): Vector3
				local brain = Brain.new(on, FIELD, START, Random.new(77))
				local position = START
				for _ = 1, 60 do
					local intent = brain:step(
						DT,
						obs(position, { stimulus(20, "driver", 6) }, {
							sounder = follower({
								slot = 3,
								leader = leader,
								centroid = leaderAt,
								formation = formation,
							}),
						})
					)
					position += intent.targetVelocity * DT
				end
				return position
			end

			local column = run("column")
			local wedge = run("wedge")
			-- The leader's axis is -Z, so "across it" is X, and the wedge's slot 3 is +7 of it.
			expect(math.abs(column.X) < math.abs(wedge.X)).to.equal(true)
			expect(flatDistance(column, wedge) > 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-behaviour: slot 3 after 1 s -- column %.1f studs off the axis, wedge %.1f",
					math.abs(column.X),
					math.abs(wedge.X)
				)
			)
		end)
	end)

	-- ------------------------------------------------------------------ the drawn animal
	describe("boar behaviour: the drawn animal puts its head up", function()
		-- Section 3.6: exactly two lines, both inside the seam task 115 already built. `ALERT_CLIP`
		-- names a ROW IN `CLIPS`, which is the whole of this task's dependency on the drawn model --
		-- a one-word data change if the Director publishes a different clip, and no code either way.
		local function modelWith(ids)
			local model = table.clone(CONFIG.MODEL)
			model.ANIMATION_IDS = ids
			local config = table.clone(CONFIG)
			config.MODEL = model
			return config
		end

		local function published()
			local ids = table.clone(CONFIG.MODEL.ANIMATION_IDS)
			for name in pairs(CONFIG.MODEL.CLIPS) do
				ids[name] = 30000 + #name
			end
			return modelWith(ids)
		end

		local function info(extra)
			local o = {
				collapsed = false,
				deadFor = 0,
				crippled = false,
				alert = false,
				activity = nil,
				activityFor = 0,
				exitClip = nil,
				exitFor = 0,
				hitFor = 0,
				hitFromBehind = false,
				speed = 0,
				yawRate = 0,
				currentClip = nil,
				heldFor = 10,
			}
			for key, value in pairs(extra or {}) do
				o[key] = value
			end
			return o
		end

		it("draws ALERT_CLIP while it is alert, and `idle` when that clip has no id", function()
			local config = published()
			expect(config.MODEL.ALERT_CLIP).to.equal("smell") -- the Director's choice, 2026-10-04
			local name = Boar.clipFor(info({ alert = true }), config)
			expect(name).to.equal(config.MODEL.ALERT_CLIP)
			-- ...and the same animal NOT alert draws the resting clip, so the branch is the alert and
			-- not the standing.
			expect(Boar.clipFor(info({}), config)).to.equal("idle")
			-- WITH NO ID PUBLISHED the behaviour is exactly what it was before task 118: the same
			-- "if an id is missing, the current behaviour stays" rule the file already rests on.
			local bare = modelWith({ idle = 1, walk = 2 })
			expect(Boar.clipFor(info({ alert = true }), bare)).to.equal("idle")
		end)

		it("is beaten by a gait, a turn, a flinch, a cripple and a death", function()
			-- It sits after all five (section 3.6): an alert boar is standing still, so the gaits
			-- never reach it in practice -- but an animal that is alert AND moving is drawn moving,
			-- and one that is dying is drawn dying.
			local config = published()
			expect(Boar.clipFor(info({ alert = true, speed = CONFIG.SPRINT_SPEED }), config)).to.equal("run")
			expect(Boar.clipFor(info({ alert = true, yawRate = 120 }), config)).to.equal("turnLeft")
			expect(Boar.clipFor(info({ alert = true, hitFor = CONFIG.MODEL.HIT_SECONDS }), config)).to.equal("hitFront")
			expect(Boar.clipFor(info({ alert = true, crippled = true }), config)).to.equal("crippleDrag")
			expect(Boar.clipFor(info({ alert = true, collapsed = true }), config)).to.equal((Boar.deathClips(config)))
		end)
	end)

	-- ------------------------------------------------------------------ 12-15. the properties
	describe("boar behaviour: determinism, cost, the merge and the sight hook", function()
		local on = configWith(true)

		it("is deterministic: one seed, one sequence of intents", function()
			local a = Brain.new(on, FIELD, START, Random.new(99))
			local b = Brain.new(on, FIELD, START, Random.new(99))
			local threats = { stimulus(50, "shooter", 5) }
			for _ = 1, 600 do
				local first = a:step(DT, obs(START, threats))
				local second = b:step(DT, obs(START, threats))
				expect(first.state).to.equal(second.state)
				expect((first.targetVelocity - second.targetVelocity).Magnitude < EPSILON).to.equal(true)
			end
		end)

		it("costs under 150 ms for 10 000 steps with four stimuli", function()
			local brain = Brain.new(on, FIELD, START, Random.new(100))
			local threats = {
				{ id = "a", position = Vector3.new(80, 0, 0), kind = "driver", speed = 6 },
				{ id = "b", position = Vector3.new(-90, 0, 10), kind = "driver", speed = 0 },
				{ id = "c", position = Vector3.new(0, 0, 70), kind = "shooter", speed = 0 },
				{ id = "d", position = Vector3.new(30, 0, -120), kind = "shooter", speed = 3 },
			}
			local started = os.clock()
			for _ = 1, 10000 do
				brain:step(DT, obs(START, threats))
			end
			local elapsed = os.clock() - started
			expect(elapsed < 0.15).to.equal(true)
			TestKit.note(string.format("boar-behaviour: 10000 steps, 4 stimuli, %.0f ms", elapsed * 1000))
		end)

		it("merges a partial SENSE override instead of replacing the block", function()
			-- WITHOUT THE MERGE, a world passing `config = { SENSE = { ENABLED = true } }` gets a
			-- block with one key in it: every radius and every timer reads nil, which is not an
			-- error but a boar that notices nothing at any distance and never settles.
			-- IT HAS TO BE IN WORKSPACE: `Body.create` sets the network owner, and Roblox refuses
			-- that on a part that is not a descendant of Workspace. The folder is destroyed below, so
			-- nothing of this case outlives it.
			local standing = {}
			local holder = Instance.new("Folder")
			holder.Name = "BoarBehaviourMergeProbe"
			holder.Parent = workspace
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "MergeProbe",
				rng = Random.new(1),
				config = { SENSE = { ENABLED = true, SHOT_AUDIBLE_STUDS = 7 } },
				threats = function()
					return standing
				end,
				-- A ROUTE SEAM THAT ANSWERS NOTHING. `hearShot` below bolts the animal into FLEE,
				-- and FLEE asks for a route on its first step: a world without this is a nil call
				-- inside `Runtime:step`, which is a harness fault and not a finding.
				requestPath = function(_agentId, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			local merged = runtime:stats() -- forces the runtime to be real before we read its config
			expect(merged).to.be.ok()
			local handle = runtime:spawn(Vector3.new(0, FIELD.groundY, 0))
			expect(handle).to.be.ok()
			-- THE OVERRIDE APPLIED: a shot at 6 studs is heard and one at 8 is not, against the
			-- override's own SHOT_AUDIBLE_STUDS = 7 (the default is 350, so both would be heard).
			expect(runtime:hearShot(Vector3.new(6, FIELD.groundY, 0))).to.equal(1)
			expect(runtime:hearShot(Vector3.new(8, FIELD.groundY, 0))).to.equal(0)

			-- ...AND EVERY OTHER NUMBER IS STILL THE DEFAULT, which is the half the merge is FOR and
			-- the half a replaced block fails: `NOTICE_STANDING` is nil in a block of two keys, so
			-- the animal notices nothing at any distance. Stepped by hand -- this runtime is not
			-- running -- and read back through `perceptionOf`, the one door there is.
			standing = { { id = "man", position = Vector3.new(24, FIELD.groundY, 0), kind = "shooter" } }
			runtime:step(DT)
			runtime:step(DT)
			local perception = runtime:perceptionOf(handle.id)
			expect(perception).to.be.ok()
			expect(perception.reaction).to.equal("alert")

			runtime:destroy()
			holder:Destroy()
		end)

		it("gates a notice on line of sight when REQUIRE_SIGHT asks it to, and only then", function()
			local sighted = configWith(true, { REQUIRE_SIGHT = true })
			local man = { stimulus(24, "shooter") }
			local calls = 0
			local blocked = function()
				calls += 1
				return true -- something solid, every time
			end
			local clear = function()
				calls += 1
				return false
			end
			expect(Brain.perceive(START, man, sighted, blocked).reaction).to.equal("none")
			expect(Brain.perceive(START, man, sighted, clear).reaction).to.equal("alert")
			-- ...and a FLUSH is never gated: a boar at 14 studs has smelt and heard him whatever is
			-- in the way.
			expect(Brain.perceive(START, { stimulus(14, "shooter") }, sighted, blocked).reaction).to.equal("flee")
			-- With the dial at its shipped value the probe is not consulted at all.
			calls = 0
			expect(Brain.perceive(START, man, configWith(true), blocked).reaction).to.equal("alert")
			expect(calls).to.equal(0)

			-- AND IT IS ASKED ONCE PER SENSE TICK, NOT ONCE PER FRAME. One stimulus, 600 steps of
			-- 1/60 s: ten seconds, so at SENSE_INTERVAL = 0.2 that is at most 1 + 10/0.2 = 51 rays.
			local brain = Brain.new(sighted, FIELD, START, Random.new(101))
			calls = 0
			for _ = 1, 600 do
				brain:step(DT, obs(START, man, { probe = clear }))
			end
			expect(calls <= 1 + (600 * DT) / CONFIG.SENSE_INTERVAL).to.equal(true)
			TestKit.note(string.format("boar-behaviour: %d sight rays over 10 s of stepping", calls))
		end)
	end)
end
