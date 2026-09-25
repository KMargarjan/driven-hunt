-- camera_mode.spec: the camera's whole state machine and all of its maths, driven on the SERVER
-- with no client, no player and no camera. Camera.Mode is pure and requires only its Config
-- sibling, so this works the way tests/server/boar_brain.spec.luau drives the boar's brain with no
-- world -- and it is why the camera's maths is testable at all.
--
-- It reaches the module through StarterPlayer.StarterPlayerScripts, which is the TEMPLATE, not a
-- running client: safe to require here precisely because nothing happens on require.
-- Numbers are written out rather than imported for the assertion, so a config that drifts from the
-- design is a finding and not a tautology (the rule test_arena.spec already follows).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/camera.md (section 9.1)
local StarterPlayer = game:GetService("StarterPlayer")

local cameraFolder = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Camera")
local Mode = require(cameraFolder:WaitForChild("Mode"))
local Config = require(cameraFolder:WaitForChild("Config"))

local NONE = { aiming = false, alive = true, hasCharacter = true, lookDelta = Vector2.zero }

local function input(overrides)
	local merged = table.clone(NONE)
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

-- Steps until `predicate(state)` or `seconds` of simulated time have passed. Returns the state and
-- the simulated seconds it took.
local function run(state, stepInput, dt: number, seconds: number, predicate)
	local elapsed = 0
	while elapsed < seconds do
		state = Mode.step(state, stepInput, dt, Config)
		elapsed += dt
		if predicate and predicate(state) then
			return state, elapsed
		end
	end
	return state, elapsed
end

return function()
	describe("camera mode", function()
		it("starts in Loading, unblended and frozen", function()
			local state = Mode.initial(Config)
			expect(state.mode).to.equal("Loading")
			expect(state.blend).to.equal(0)
			expect(state.pitchDeg).to.equal(-8)
			expect(function()
				(state :: any).mode = "Third"
			end).to.throw()
		end)

		it("leaves Loading for Third as soon as there is a living character", function()
			local state = Mode.step(Mode.initial(Config), input(), 1 / 60, Config)
			expect(state.mode).to.equal("Third")
			expect(state.blend).to.equal(0)
		end)

		it("reaches blend 1 after exactly AIM_BLEND_SECONDS, at any frame rate", function()
			for _, dt in ipairs({ 1 / 30, 1 / 240 }) do
				local state = Mode.step(Mode.initial(Config), input(), dt, Config)
				local aiming = input({ aiming = true })
				state = Mode.step(state, aiming, dt, Config)
				expect(state.mode).to.equal("Aiming")

				local reached
				state, reached = run(state, aiming, dt, 2, function(s)
					return s.blend >= 1
				end)
				expect(state.blend).to.equal(1) -- exactly 1, not 0.999
				-- 0.20 s of accumulated dt, give or take the one step already taken above.
				expect(math.abs(reached - 0.2) <= dt * 2).to.equal(true)

				-- and it does not overshoot
				state = Mode.step(state, aiming, dt, Config)
				expect(state.blend).to.equal(1)
			end
		end)

		it("returns to 0 in the same time, and from wherever the reversal happened", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			local aiming = input({ aiming = true })
			state = run(state, aiming, dt, 0.08) -- part way in
			expect(state.blend > 0.2 and state.blend < 0.8).to.equal(true)
			local reversalFrom = state.blend

			local back, took = run(state, input(), dt, 1, function(s)
				return s.blend <= 0
			end)
			expect(back.blend).to.equal(0)
			expect(back.mode).to.equal("Third")
			-- From 0.4, not from 1: the trip back is proportional to where it was.
			expect(took <= reversalFrom * 0.2 + dt * 2).to.equal(true)
		end)

		it("goes Dead when the character dies, and ignores aim entirely while dead", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			state = Mode.step(state, input({ aiming = true }), dt, Config)
			expect(state.mode).to.equal("Aiming")

			local dead = input({ alive = false, aiming = true })
			state = Mode.step(state, dead, dt, Config)
			expect(state.mode).to.equal("Dead")
			state = run(state, dead, dt, 1)
			expect(state.mode).to.equal("Dead")
			expect(state.blend).to.equal(0) -- the blend decays even while dead
		end)

		it("takes no look input while dead", function()
			-- Design section 4.1: Dead is "no orbit, no input". Round 1, finding 4 was that only
			-- Loading suppressed the look, so a dead player could still swing the view.
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			state = Mode.step(state, input({ lookDelta = Vector2.new(200, 50) }), dt, Config)
			local aliveYaw, alivePitch = state.yawDeg, state.pitchDeg
			expect(aliveYaw ~= 0).to.equal(true) -- the look works while alive

			local dead = input({ alive = false, lookDelta = Vector2.new(400, 120) })
			state = Mode.step(state, dead, dt, Config)
			expect(state.mode).to.equal("Dead")
			expect(state.yawDeg).to.equal(aliveYaw)
			expect(state.pitchDeg).to.equal(alivePitch)
			state = run(state, dead, dt, 0.5)
			expect(state.yawDeg).to.equal(aliveYaw)
		end)

		it("goes Loading whenever the character is gone, from every other mode", function()
			local dt = 1 / 60
			local gone = input({ hasCharacter = false })
			for _, start in ipairs({ "Third", "Aiming", "Dead" }) do
				local state = Mode.step(Mode.initial(Config), input(), dt, Config)
				if start == "Aiming" then
					state = Mode.step(state, input({ aiming = true }), dt, Config)
				elseif start == "Dead" then
					state = Mode.step(state, input({ alive = false }), dt, Config)
				end
				expect(state.mode).to.equal(start)
				expect(Mode.step(state, gone, dt, Config).mode).to.equal("Loading")
			end
		end)

		it("clamps pitch and wraps yaw, however hard the mouse is thrown", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)

			local up = Mode.step(state, input({ lookDelta = Vector2.new(0, -10000) }), dt, Config)
			expect(up.pitchDeg).to.equal(78)
			local down = Mode.step(state, input({ lookDelta = Vector2.new(0, 10000) }), dt, Config)
			expect(down.pitchDeg).to.equal(-72)

			-- 100 full turns at 0.25 deg/pixel: 1440 pixels is 360 degrees.
			local spun = state
			for _ = 1, 100 do
				spun = Mode.step(spun, input({ lookDelta = Vector2.new(1440, 0) }), dt, Config)
			end
			expect(spun.yawDeg > -180 and spun.yawDeg <= 180).to.equal(true)
		end)

		it("scales sensitivity with the zoom, through the one conversion", function()
			expect(Mode.sensitivityScale(70, Config)).to.equal(1)
			local aimed = Mode.sensitivityScale(50, Config)
			-- tan(25)/tan(35) = 0.6658. A degrees/radians mix-up misses this by an order of magnitude.
			expect(aimed > 0.66 and aimed < 0.67).to.equal(true)
		end)

		it("puts the third-person camera behind the pivot, inside the hard clamp", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			local root = CFrame.new(0, 5, 0)
			local pivot, cf, fov = Mode.cameraCFrame(root, state, Config)

			expect(pivot.Y > root.Position.Y).to.equal(true)
			expect(fov).to.equal(70)
			local distance = (cf.Position - root.Position).Magnitude
			expect(distance > 8).to.equal(true) -- genuinely behind, not on top of the character
			expect(distance <= 14.5).to.equal(true) -- MAX_DISTANCE_STUDS
			-- And the number that matters to another system: the shotgun's server rejects a fire
			-- request whose origin is more than CAMERA_ORIGIN_TOLERANCE = 30 studs from the root
			-- (docs/design/shotgun.md section 11). An honest shot must never be refused "origin-far".
			expect(distance < 30).to.equal(true)
		end)

		it("puts the aimed camera at the eye, with the aim field of view", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			local aiming = input({ aiming = true })
			state = run(state, aiming, dt, 1, function(s)
				return s.blend >= 1
			end)

			local root = CFrame.new(0, 5, 0)
			local pivot, cf, fov = Mode.cameraCFrame(root, state, Config)
			expect(fov).to.equal(50)
			expect((cf.Position - pivot).Magnitude <= 0.5).to.equal(true)
		end)

		it("never mutates the state it was given", function()
			local dt = 1 / 60
			local state = Mode.step(Mode.initial(Config), input(), dt, Config)
			local before = { state.mode, state.blend, state.yawDeg, state.pitchDeg }
			local next = Mode.step(state, input({ aiming = true, lookDelta = Vector2.new(50, 50) }), dt, Config)
			expect(next).never.to.equal(state)
			expect(state.mode).to.equal(before[1])
			expect(state.blend).to.equal(before[2])
			expect(state.yawDeg).to.equal(before[3])
			expect(state.pitchDeg).to.equal(before[4])
		end)

		it("keeps the config frozen", function()
			expect(function()
				(Config :: any).FOV_AIM_DEG = 10
			end).to.throw()
		end)

		it("steps 10000 times in under 100 ms", function()
			local state = Mode.initial(Config)
			local stepInput = input({ lookDelta = Vector2.new(2, 1) })
			local started = os.clock()
			for _ = 1, 10000 do
				state = Mode.step(state, stepInput, 1 / 60, Config)
			end
			expect(os.clock() - started < 0.1).to.equal(true)
		end)
	end)

	-- Task 30: the angles that point the CAMERA at a target. It is what makes an end-to-end
	-- "shoot the thing you are looking at" test possible at all, because the harness cannot aim.
	-- Design: docs/design/hit-zones.md section 14 item D.
	describe("aiming at a point", function()
		local function errorDegrees(rootCFrame: CFrame, target: Vector3, state): number
			local _, desired = Mode.cameraCFrame(rootCFrame, state, Config)
			local dot = desired.LookVector:Dot((target - desired.Position).Unit)
			return math.deg(math.acos(math.clamp(dot, -1, 1)))
		end

		it("points the CAMERA at the target, not the character", function()
			local root = CFrame.new(0, 3, 0)
			for _, target in ipairs({
				Vector3.new(0, 3, -40),
				Vector3.new(25, 3, 25),
				Vector3.new(-60, 12, -10),
				Vector3.new(0, 3, 30),
			}) do
				local aimed = Mode.anglesToward(Mode.initial(Config), root, target, Config)
				local err = errorDegrees(root, target, aimed)
				-- Six passes; four left 0.08 degrees on this geometry, which is where the number in
				-- Mode.anglesToward comes from.
				expect(err < 0.02).to.equal(true)
			end
		end)

		it("earns its iteration: aiming the pivot alone would miss", function()
			-- The camera sits THIRD_DISTANCE_STUDS behind the pivot and SHOULDER_STUDS.X to its
			-- right, so the naive angles -- the ones that point the pivot at the target -- leave the
			-- camera pointing degrees away. This is the test that says the loop is not decoration.
			local root = CFrame.new(0, 3, 0)
			local target = Vector3.new(0, 3, -20)
			local pivot = root.Position + Vector3.new(0, Config.PIVOT_HEIGHT_STUDS, 0)
			local direction = (target - pivot).Unit
			local naive = table.freeze({
				mode = "Third",
				blend = 0,
				yawDeg = math.deg(math.atan2(-direction.X, -direction.Z)),
				pitchDeg = math.deg(math.asin(direction.Y)),
				sinceModeChange = 0,
			})
			local naiveError = errorDegrees(root, target, naive)
			local aimedError = errorDegrees(root, target, Mode.anglesToward(Mode.initial(Config), root, target, Config))
			print(string.format("[camera_mode] aim error: naive %.2f deg, iterated %.4f deg", naiveError, aimedError))
			expect(naiveError > 3).to.equal(true)
			expect(aimedError < 0.02).to.equal(true)
		end)

		it("cannot centre a target INSIDE the boom, and says so by staying finite", function()
			-- The camera orbits the pivot at THIRD_DISTANCE_STUDS. A target nearer than that is
			-- inside the orbit, so no yaw and pitch put it in the middle of the screen -- turning
			-- toward it moves the camera away from it. MEASURED: the iteration oscillates there
			-- instead of converging (four passes left 0.08 degrees at 20 studs and several degrees
			-- at 8). What it must never do is return NaN or an unclamped angle, and that is what is
			-- asserted; aiming at something you are standing on is not a shot anyone takes.
			local root = CFrame.new(0, 3, 0)
			local near = Mode.anglesToward(Mode.initial(Config), root, Vector3.new(3, 3, 8), Config)
			expect(near.yawDeg == near.yawDeg).to.equal(true) -- not NaN
			expect(near.pitchDeg == near.pitchDeg).to.equal(true)
			expect(near.yawDeg > -180 and near.yawDeg <= 180).to.equal(true)
			expect(near.pitchDeg >= -72 and near.pitchDeg <= 78).to.equal(true)
		end)

		it("clamps the pitch and wraps the yaw, like every other angle in this module", function()
			local root = CFrame.new(0, 3, 0)
			local up = Mode.anglesToward(Mode.initial(Config), root, Vector3.new(0, 400, 0), Config)
			expect(up.pitchDeg <= 78).to.equal(true) -- PITCH_MAX_DEG
			local down = Mode.anglesToward(Mode.initial(Config), root, Vector3.new(0, -400, 0), Config)
			expect(down.pitchDeg >= -72).to.equal(true) -- PITCH_MIN_DEG

			-- Straight behind the character is yaw 180, which must come back as 180, not -180 or 540.
			local behind = Mode.anglesToward(Mode.initial(Config), root, Vector3.new(0, 3, 40), Config)
			expect(behind.yawDeg > -180 and behind.yawDeg <= 180).to.equal(true)
		end)

		it("keeps the mode and the blend, and returns a frozen state", function()
			local aiming = Mode.step(
				Mode.step(Mode.initial(Config), input(), 1 / 60, Config),
				input({ aiming = true }),
				1 / 60,
				Config
			)
			local aimed = Mode.anglesToward(aiming, CFrame.new(0, 3, 0), Vector3.new(0, 3, -30), Config)
			expect(aimed.mode).to.equal(aiming.mode)
			expect(aimed.blend).to.equal(aiming.blend)
			expect(function()
				aimed.yawDeg = 0
			end).to.throw()
		end)

		it("leaves the angles alone when the target is where the camera already is", function()
			local root = CFrame.new(0, 3, 0)
			local state = Mode.initial(Config)
			local _, desired = Mode.cameraCFrame(root, state, Config)
			local aimed = Mode.anglesToward(state, root, desired.Position, Config)
			expect(aimed.yawDeg).to.equal(state.yawDeg)
			expect(aimed.pitchDeg).to.equal(state.pitchDeg)
		end)
	end)
end
