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
end
