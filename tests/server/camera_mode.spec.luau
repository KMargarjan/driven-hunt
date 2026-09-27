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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local ServerScriptService = game:GetService("ServerScriptService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
-- THE GUN'S OWN BEAD EXPRESSION, not a copy of its numbers: the sight picture this file asserts is
-- only right if it is built from the same place the gun's bead is (docs/design/camera.md 6.5).
local Shape = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("Shape"))

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

-- THE ON BRANCH, BY PARAMETER (docs/design/feature-flags.md section 13.3). `FIRST_PERSON` is born
-- OFF, so a spec that read the live flag could only ever test one of the two cameras -- which is
-- exactly why `Camera.Config.FIRST_PERSON` is read ONCE at the boundary and passed inward as
-- `config`. Every case below that names a branch drives its own table, so there is nothing to
-- restore and nothing that depends on what the place booted with.
local firstPerson = table.clone(Config) :: any
firstPerson.FIRST_PERSON = true
table.freeze(firstPerson)

-- THE PIECES A PLAYER AIMS WITH, and the one they rest their cheek on. `Shape.pieces` is the gun's
-- own list, so these follow the gun rather than a box copied into this file.
local AIMED_WITH = { BarrelLeft = true, BarrelRight = true, Rib = true, Bead = true }

-- The camera-space Z of every corner of one piece, given the pose the viewmodel is drawn at. A
-- piece's `offset` carries its own rotation (a barrel is a cylinder lying along Z), so the corners
-- are taken through it rather than from an axis-aligned box.
local function pieceCornerZ(pose: CFrame, piece): { number }
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local corner = piece.offset
					* CFrame.new(sx * piece.size.X / 2, sy * piece.size.Y / 2, sz * piece.size.Z / 2)
				table.insert(out, (pose * corner).Position.Z)
			end
		end
	end
	return out
end

local function pieceNamed(name: string)
	for _, piece in ipairs(Shape.pieces(Shotgun.CONFIG)) do
		if piece.name == name then
			return piece
		end
	end
	return nil
end

-- A state at a given blend, with every cosmetic term at its exact rest.
local function stateAtBlend(blend: number)
	local state = table.clone(Mode.initial(Config)) :: any
	state.mode = if blend > 0 then "Aiming" else "Third"
	state.blend = blend
	return table.freeze(state)
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
	-- ------------------------------------------------------------------ first person (task 89, S1)
	describe("first person, by parameter", function()
		it("puts the camera at the eye at EVERY blend, inside every tolerance that binds", function()
			-- The point of the branch: there is no boom to ease along, so blend moves the field of
			-- view and the viewmodel and NOT the camera. A player who aims has the same eye.
			local root = CFrame.new(10, 5, -3)
			for _, blend in ipairs({ 0, 0.25, 0.5, 1 }) do
				local pivot, desired = Mode.cameraCFrame(root, stateAtBlend(blend), firstPerson)
				local fromPivot = (desired.Position - pivot).Magnitude
				expect(fromPivot <= Config.AIM_PIVOT_FORWARD_STUDS + 1e-4).to.equal(true)
				local fromRoot = (desired.Position - root.Position).Magnitude
				expect(fromRoot < 2.0).to.equal(true)
				-- The two that would let a shot be refused: the camera's own hard clamp, and the
				-- shotgun validator's CAMERA_ORIGIN_TOLERANCE = 30 studs (docs/design/shotgun.md
				-- section 11), which the fire origin is measured against.
				expect(fromRoot < Config.MAX_DISTANCE_STUDS).to.equal(true)
				expect(fromRoot < 30).to.equal(true)
			end
		end)

		-- ------------------------------------------------------------ no jump on ADS (task 92)
		it("moves the gun and NOT the aim point when right mouse goes down", function()
			-- KAREN, after playing S2 (2026-09-27): "I expect when clicking mouse right the weapon
			-- height (aim dot) is in same level as before clicking mouse right."
			--
			-- So this asserts the property her sentence describes, in the only place it can be
			-- asserted exactly: the eye and the look direction are INDEPENDENT OF THE BLEND, so the
			-- world point under the screen centre is the same before the click, during the ease and
			-- after it. The client spec measures the same thing in a live session, in studs.
			local root = CFrame.new(-4, 3, 17)
			local _, atRest = Mode.cameraCFrame(root, stateAtBlend(0), firstPerson)
			for _, blend in ipairs({ 0.01, 0.25, 0.5, 0.99, 1 }) do
				local _, aimed = Mode.cameraCFrame(root, stateAtBlend(blend), firstPerson)
				expect((aimed.Position - atRest.Position).Magnitude).to.equal(0)
				expect((aimed.LookVector - atRest.LookVector).Magnitude).to.equal(0)
				-- ...and therefore the point 60 studs down the centre of the screen, which is what a
				-- player is actually looking at when they click.
				local was = atRest.Position + atRest.LookVector * 60
				local is = aimed.Position + aimed.LookVector * 60
				expect((is - was).Magnitude).to.equal(0)
			end
			-- IT IS THE GUN THAT MOVES, or this case is a claim that nothing happens at all: the
			-- viewmodel's pose at blend 1 is a long way from the carry pose.
			local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
			local carry = Mode.viewmodelOffset(stateAtBlend(0), sight, firstPerson)
			local aimedPose = Mode.viewmodelOffset(stateAtBlend(1), sight, firstPerson)
			expect((aimedPose.Position - carry.Position).Magnitude > 0.5).to.equal(true)
			-- ...and the THIRD-PERSON branch does move the eye, which is what the flag is for and
			-- what makes the assertions above a measurement rather than a description of both.
			local _, thirdRest = Mode.cameraCFrame(root, stateAtBlend(0), Config)
			local _, thirdAimed = Mode.cameraCFrame(root, stateAtBlend(1), Config)
			expect((thirdAimed.Position - thirdRest.Position).Magnitude > 5).to.equal(true)
		end)

		-- ------------------------------------------------------ the raise, one swing (task 95)
		it("swings from the carry into the aim without ever pointing at the sky", function()
			-- KAREN'S REFERENCE, FRAME BY FRAME: right mouse down and the gun comes up in about a
			-- quarter of a second, ONE eased swing, the barrels turning from pointing-left to
			-- pointing-forward as they rise. What must never happen in between is the muzzle lifting
			-- toward the sky -- the thing that makes a viewmodel look like it is being thrown.
			local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
			local worst, worstAt = -90, 0
			for step = 0, 20 do
				local blend = step / 20
				local pose = Mode.viewmodelOffset(stateAtBlend(blend), sight, firstPerson)
				local muzzle = (pose * CFrame.new(0, 0, -Shotgun.CONFIG.HANDLE_SIZE.Z / 2)).Position
				local action = (pose * CFrame.new(0, 0, Shotgun.CONFIG.HANDLE_SIZE.Z / 2)).Position
				local elevation = math.deg(math.asin(math.clamp((muzzle - action).Unit.Y, -1, 1)))
				if elevation > worst then
					worst, worstAt = elevation, blend
				end
			end
			-- The carry itself is the highest the muzzle ever gets, and it is a few degrees.
			expect(worst < 20).to.equal(true)
			TestKit.note(string.format("task95 raise: muzzle peaks at %.1f deg up, at blend %.2f", worst, worstAt))

			-- ...AND IT IS ONE MOVE, NOT A WANDER: the gun's own position sweeps monotonically from
			-- the carry to the aimed pose, with no doubling back.
			local previous, backwards = nil, 0
			local aimed = Mode.viewmodelOffset(stateAtBlend(1), sight, firstPerson).Position
			for step = 0, 20 do
				local here = Mode.viewmodelOffset(stateAtBlend(step / 20), sight, firstPerson).Position
				local left = (aimed - here).Magnitude
				if previous and left > previous + 1e-4 then
					backwards += 1
				end
				previous = left
			end
			expect(backwards).to.equal(0)
		end)

		it("raises faster than it lowers, and the OFF branch keeps its one number", function()
			expect(Mode.blendSeconds(firstPerson, true)).to.equal(firstPerson.AIM_RAISE_SECONDS)
			expect(Mode.blendSeconds(firstPerson, false)).to.equal(firstPerson.AIM_LOWER_SECONDS)
			expect(firstPerson.AIM_LOWER_SECONDS < firstPerson.AIM_RAISE_SECONDS).to.equal(true)
			expect(firstPerson.AIM_RAISE_SECONDS <= 0.3).to.equal(true) -- "very fast", not a drift
			-- The third-person camera Karen accepted on 2026-09-25 keeps ONE number both ways.
			expect(Mode.blendSeconds(Config, true)).to.equal(Config.AIM_BLEND_SECONDS)
			expect(Mode.blendSeconds(Config, false)).to.equal(Config.AIM_BLEND_SECONDS)

			-- ...and the reducer really uses them: the raise takes longer than the fall, measured in
			-- simulated seconds rather than read off the table.
			local function secondsTo(aiming: boolean, from)
				local state, elapsed = from, 0
				while (aiming and state.blend < 1) or (not aiming and state.blend > 0) do
					state = Mode.step(state, input({ aiming = aiming }), 1 / 240, firstPerson)
					elapsed += 1 / 240
					if elapsed > 2 then
						break
					end
				end
				return state, elapsed
			end
			local start = Mode.step(Mode.initial(firstPerson), input(), 1 / 240, firstPerson)
			local up, upSeconds = secondsTo(true, start)
			local _, downSeconds = secondsTo(false, up)
			expect(math.abs(upSeconds - firstPerson.AIM_RAISE_SECONDS) < 0.02).to.equal(true)
			expect(math.abs(downSeconds - firstPerson.AIM_LOWER_SECONDS) < 0.02).to.equal(true)
			expect(downSeconds < upSeconds).to.equal(true)
		end)

		-- ------------------------------------------------------------------ recoil (task 92)
		describe("recoil", function()
			-- KAREN, after playing S2: "shooting has to have recoil a bit".
			local function stepFor(state, seconds: number, dt: number)
				local elapsed = 0
				local worstGun, worstCam = 0, 0
				while elapsed < seconds do
					state = Mode.step(state, input({ aiming = true }), dt, firstPerson)
					worstGun = math.max(worstGun, math.abs(state.recoilGunPitchDeg))
					worstCam = math.max(worstCam, math.abs(state.recoilCamPitchDeg))
					elapsed += dt
				end
				return state, worstGun, worstCam
			end

			it("kicks the gun and the view, then returns the aim point EXACTLY", function()
				local root = CFrame.new(0, 5, 0)
				local before = Mode.step(Mode.initial(firstPerson), input({ aiming = true }), 1 / 60, firstPerson)
				expect(Mode.recoiling(before)).to.equal(false)
				local _, aimBefore = Mode.cameraCFrame(root, before, firstPerson)

				local kicked = Mode.kick(before, firstPerson)
				expect(kicked.recoilGunPitchDeg).to.equal(firstPerson.RECOIL_GUN_PITCH_DEG)
				expect(kicked.recoilGunBackStuds).to.equal(firstPerson.RECOIL_GUN_BACK_STUDS)
				expect(kicked.recoilCamPitchDeg).to.equal(firstPerson.RECOIL_CAM_PITCH_DEG)
				expect(Mode.recoiling(kicked)).to.equal(true)
				-- THE VIEW REALLY LIFTS, or "recoil" is a number nobody can see: the camera's look
				-- direction is no longer where it was.
				local _, aimKicked = Mode.cameraCFrame(root, kicked, firstPerson)
				expect(aimKicked.LookVector:Dot(aimBefore.LookVector) < 0.9999).to.equal(true)
				-- ...and the gun moved in its own frame too, up and back.
				local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
				expect(Mode.viewmodelOffset(kicked, sight, firstPerson)).never.to.equal(
					Mode.viewmodelOffset(before, sight, firstPerson)
				)

				-- AND IT COMES ALL THE WAY HOME. Not "close to zero": exactly zero, because the
				-- spring snaps at RECOIL_REST_EPSILON -- which is what lets the bead return to the
				-- point it left rather than somewhere a fraction of a degree off it.
				local settled, worstGun, worstCam = stepFor(kicked, 1.0, 1 / 60)
				expect(Mode.recoiling(settled)).to.equal(false)
				expect(settled.recoilGunPitchDeg).to.equal(0)
				expect(settled.recoilCamPitchDeg).to.equal(0)
				expect(settled.recoilGunBackStuds).to.equal(0)
				local _, aimAfter = Mode.cameraCFrame(root, settled, firstPerson)
				expect((aimAfter.Position - aimBefore.Position).Magnitude).to.equal(0)
				expect((aimAfter.LookVector - aimBefore.LookVector).Magnitude).to.equal(0)
				-- CRITICALLY DAMPED means it never goes past where the kick put it, in either
				-- direction: no overshoot, so no wobble to watch.
				expect(worstGun <= firstPerson.RECOIL_GUN_PITCH_DEG + 1e-6).to.equal(true)
				expect(worstCam <= firstPerson.RECOIL_CAM_PITCH_DEG + 1e-6).to.equal(true)
				TestKit.note(
					string.format(
						"task92 recoil: gun %.2f deg / %.3f studs, view %.2f deg, home in under 1.0 s at 60 fps",
						firstPerson.RECOIL_GUN_PITCH_DEG,
						firstPerson.RECOIL_GUN_BACK_STUDS,
						firstPerson.RECOIL_CAM_PITCH_DEG
					)
				)
			end)

			it("settles the same way at 240, 60 and 20 fps, and clamps a doublet", function()
				-- FRAME-RATE INDEPENDENT, which is the one thing a hand-rolled spring gets wrong.
				for _, dt in ipairs({ 1 / 240, 1 / 60, 1 / 20 }) do
					local settled = (stepFor(Mode.kick(Mode.initial(firstPerson), firstPerson), 1.0, dt))
					expect(Mode.recoiling(settled)).to.equal(false)
				end
				-- TWO BARRELS, A TENTH OF A SECOND APART: the offsets add, and the ceiling is what
				-- keeps the view on the animal. Five kicks with no time between them is the worst
				-- case the rate limit allows and it still stops at the ceiling.
				local state = Mode.initial(firstPerson)
				for _ = 1, 5 do
					state = Mode.kick(state, firstPerson)
				end
				expect(state.recoilGunPitchDeg).to.equal(firstPerson.RECOIL_MAX_GUN_PITCH_DEG)
				expect(state.recoilCamPitchDeg).to.equal(firstPerson.RECOIL_MAX_CAM_PITCH_DEG)
				expect(state.recoilGunBackStuds).to.equal(firstPerson.RECOIL_MAX_GUN_BACK_STUDS)
				-- ...and the ceiling is a ceiling on something: one kick is under it.
				expect(firstPerson.RECOIL_GUN_PITCH_DEG < firstPerson.RECOIL_MAX_GUN_PITCH_DEG).to.equal(true)
			end)

			it("does nothing at all in the third-person branch", function()
				-- Task 89 promised the flag-off camera is the one Karen accepted on 2026-09-25,
				-- unchanged, and a kick is something a player sees. By parameter, so the promise is
				-- tested while the flag itself sits at one value.
				local before = Mode.initial(Config)
				expect(Mode.kick(before, Config)).to.equal(before)
				expect(Mode.recoiling(before)).to.equal(false)
			end)
		end)

		it("disagrees with the third-person branch, which is the whole point of the flag", function()
			-- A case that would pass with the branch deleted is worth nothing: at blend 0 the two
			-- cameras are a boom apart, and this is the number that says the switch does something.
			local root = CFrame.new(0, 0, 0)
			local _, on = Mode.cameraCFrame(root, stateAtBlend(0), firstPerson)
			local _, off = Mode.cameraCFrame(root, stateAtBlend(0), Config)
			expect((on.Position - off.Position).Magnitude > 10).to.equal(true)
			-- ...and they agree about where the player is LOOKING, in both branches.
			expect(on.LookVector:Dot(off.LookVector) > 0.999).to.equal(true)
		end)

		it("eases the field of view the same way in both branches, and ends exactly", function()
			for _, cfg in ipairs({ Config, firstPerson }) do
				expect(Mode.fovFor(0, cfg)).to.equal(cfg.FOV_THIRD_DEG)
				expect(Mode.fovFor(1, cfg)).to.equal(cfg.FOV_AIM_DEG)
				local half = Mode.fovFor(0.5, cfg)
				expect(half < cfg.FOV_THIRD_DEG and half > cfg.FOV_AIM_DEG).to.equal(true)
			end
		end)

		it("carries the gun ACROSS THE LOWER LEFT, muzzle to the left and a little up", function()
			local carry = Mode.carryOffset(firstPerson)
			-- TASK 95, AND IT IS THE REFERENCE'S POSE RATHER THAN A SIGN CONVENTION: panel A of
			-- `REF-SHEET-carry-aim.jpg` has the gun lying across the lower left, the action below the
			-- bottom edge left of centre and the barrels leaving the frame at the LEFT. So the two
			-- ends are asserted where the picture puts them, in the camera's own frame.
			expect(carry.Position).to.equal(Config.VIEWMODEL_CARRY_POS_STUDS)
			local half = Shotgun.CONFIG.HANDLE_SIZE.Z / 2
			local muzzle = (carry * CFrame.new(0, 0, -half)).Position
			local action = (carry * CFrame.new(0, 0, half)).Position
			-- THE MUZZLE IS LEFT, AND FURTHER AWAY: it runs off toward the left edge, which is what
			-- makes the barrel taper across the frame instead of pointing at the viewer.
			expect(muzzle.X < -1.5).to.equal(true)
			expect(muzzle.Z < action.Z).to.equal(true)
			-- ...AND A LITTLE UP, never at the sky: between 2 and 20 degrees above the horizon.
			local elevation = math.deg(math.asin(math.clamp((muzzle - action).Unit.Y, -1, 1)))
			expect(elevation > 2 and elevation < 20).to.equal(true)
			-- THE ACTION IS CLOSE, LOW AND LEFT OF CENTRE -- the corner of the frame the picture puts
			-- it in -- and inside the near plane's margin, which is what stops it being sliced.
			expect(action.Y < 0).to.equal(true)
			expect(action.X < 0).to.equal(true)
			expect(action.Z < -firstPerson.NEAR_PLANE_MARGIN_STUDS).to.equal(true)
			TestKit.note(
				string.format(
					"task95 carry: muzzle %.1f deg left and %.1f deg up, action at %.2f studs",
					math.deg(math.atan2(-muzzle.X, -muzzle.Z)),
					elevation,
					action.Magnitude
				)
			)
			-- The rotation, rebuilt here from the SAME three numbers in degrees. A second
			-- conversion, a missing `math.rad` or a 2x slip moves the muzzle by a stud and fails
			-- this -- which is the defect Task 19's cone units cost a round.
			local expected = CFrame.new(Config.VIEWMODEL_CARRY_POS_STUDS)
				* CFrame.Angles(
					math.rad(Config.CARRY_PITCH_DEG),
					math.rad(Config.CARRY_YAW_DEG),
					math.rad(Config.CARRY_ROLL_DEG)
				)
			local a = { carry:GetComponents() }
			local b = { expected:GetComponents() }
			for index = 1, 12 do
				expect(math.abs(a[index] - b[index]) < 1e-6).to.equal(true)
			end
			-- and the carry pose is the OFF branch's hip pose only in the OFF branch
			expect(Mode.viewmodelOffset(stateAtBlend(0), nil, Config)).to.equal(Config.VIEWMODEL_HIP_OFFSET)
			expect(Mode.viewmodelOffset(stateAtBlend(0), nil, firstPerson)).to.equal(carry)
			-- THE MUZZLE POINTS IN, not out: the gun is held on the right and crosses toward the
			-- centre-left, which is what "right hand grip, left hand on the pipes" looks like. The
			-- position's sign alone would pass with the gun aimed off the right edge of the screen.
			local muzzleDirection = carry.LookVector
			expect(muzzleDirection.X < 0).to.equal(true)
			expect(muzzleDirection.Z < 0).to.equal(true) -- still forward, not across the player
		end)

		it("keeps everything a player aims with clear of the near plane, in both poses", function()
			-- docs/research/2026-09-27-first-person-viewmodel.md section 8: the near plane is 0.1
			-- studs and the gun is 4.4 studs long, so a pose that is a little wrong slices it on
			-- screen. This is that risk made mechanical.
			--
			-- ON THE GUN'S OWN PIECES, AND NOT ON ONE BOX ROUND THE WHOLE GUN (the second build round
			-- of task 90). The design asserts the whole box (section 9.1 item 8) -- and that rule
			-- forbids the very picture Karen accepted, because a cheek weld puts the STOCK behind the
			-- eye. What must never be sliced is what she looks THROUGH: the two barrels, the rib and
			-- the bead. The case below asserts the other half, that the stock really is behind the
			-- camera when aiming, so nothing was loosened -- it was split in two.
			local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
			local poses = {
				{ name = "carry", pose = Mode.viewmodelOffset(stateAtBlend(0), sight, firstPerson) },
				{ name = "aimed", pose = Mode.viewmodelOffset(stateAtBlend(1), sight, firstPerson) },
			}
			local worst, worstWhere = -math.huge, ""
			for _, entry in ipairs(poses) do
				local seen = 0
				for _, piece in ipairs(Shape.pieces(Shotgun.CONFIG)) do
					if AIMED_WITH[piece.name] then
						seen += 1
						for _, z in ipairs(pieceCornerZ(entry.pose, piece)) do
							if z > worst then
								worst, worstWhere = z, string.format("%s %s", entry.name, piece.name)
							end
							expect(z <= -firstPerson.NEAR_PLANE_MARGIN_STUDS).to.equal(true)
						end
					end
				end
				-- the filter really reached the pieces it names: two barrels, a rib and a bead
				expect(seen).to.equal(4)
			end
			TestKit.note(
				string.format(
					"task90: nearest aimed-with corner %.3f studs (%s), margin %.2f, eye relief %.2f",
					worst,
					worstWhere,
					firstPerson.NEAR_PLANE_MARGIN_STUDS,
					firstPerson.EYE_RELIEF_STUDS
				)
			)
		end)

		it("puts the stock behind the eye when aiming, which is what a cheek weld is", function()
			-- KAREN'S ACCEPTANCE PICTURE, as an assertion
			-- (<assets-dir>/references/inspiration-2026-09-27/ads-target-karen.jpg): the barrels fill
			-- the lower centre and run away to the bead, and almost none of the stock is visible
			-- because it is under the cheek. If somebody pushes the eye back to where the first build
			-- round had it -- a whole gun behind the breech, the stock a plank across the lower half
			-- -- this fails.
			local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
			local pose = Mode.viewmodelOffset(stateAtBlend(1), sight, firstPerson)
			local stock = pieceNamed("Stock")
			expect(stock).to.be.ok()
			local rearmost = -math.huge
			for _, z in ipairs(pieceCornerZ(pose, stock)) do
				rearmost = math.max(rearmost, z)
			end
			expect(rearmost > 0).to.equal(true)
			-- ...and the carry pose is NOT a cheek weld: there the whole gun is out in front, which
			-- is what "carried" means and what makes the two poses different pictures.
			local carry = Mode.viewmodelOffset(stateAtBlend(0), sight, firstPerson)
			local carryBarrel = pieceNamed("BarrelLeft")
			for _, z in ipairs(pieceCornerZ(carry, carryBarrel)) do
				expect(z < 0).to.equal(true)
			end
			TestKit.note(
				string.format("task90: aimed, the stock's rearmost corner is %.3f studs behind the eye", rearmost)
			)
		end)

		it("composes the cosmetic terms in one place, and they are exactly identity at rest", function()
			-- The composition order is the bug in every viewmodel, so it is written once and
			-- asserted while every term is identity. S4 fills the terms in; if any of them stopped
			-- being at rest in a build that has no maths for them, this fails.
			for _, cfg in ipairs({ Config, firstPerson }) do
				for _, blend in ipairs({ 0, 0.5, 1 }) do
					local state = stateAtBlend(blend)
					expect(state.swayDeg).to.equal(Vector2.zero)
					expect(state.bobStuds).to.equal(Vector3.zero)
					expect(state.recoilCamPitchDeg).to.equal(0)
					expect(state.openTilt).to.equal(0)
					local hip = if cfg.FIRST_PERSON then Mode.carryOffset(cfg) else cfg.VIEWMODEL_HIP_OFFSET
					local pose = hip:Lerp(cfg.VIEWMODEL_AIM_OFFSET, Mode.ease(blend))
					-- BITWISE, not within a tolerance: at rest the four cosmetic factors are
					-- identity, and the bead measurement S2 adds rests on that being exact.
					expect(Mode.viewmodelOffset(state, nil, cfg)).to.equal(pose)
				end
			end
		end)

		it("carries every cosmetic field through a step and through anglesToward", function()
			-- A field dropped by either would be `nil` in the next frame's composition. Both build
			-- their next state by cloning for exactly this reason.
			local state = Mode.step(Mode.initial(firstPerson), {
				aiming = false,
				alive = true,
				hasCharacter = true,
				lookDelta = Vector2.new(40, 10),
			}, 1 / 60, firstPerson)
			local aimed = Mode.anglesToward(state, CFrame.new(0, 0, 0), Vector3.new(0, 0, -20), firstPerson)
			for _, each in ipairs({ state, aimed }) do
				expect(each.swayDeg).to.equal(Vector2.zero)
				expect(each.bobPhase).to.equal(0)
				expect(each.bobStuds).to.equal(Vector3.zero)
				expect(each.recoilGunPitchDeg).to.equal(0)
				expect(each.recoilGunPitchRate).to.equal(0)
				expect(each.recoilGunBackStuds).to.equal(0)
				expect(each.recoilGunBackRate).to.equal(0)
				expect(each.recoilCamPitchDeg).to.equal(0)
				expect(each.recoilCamPitchRate).to.equal(0)
				expect(each.openTilt).to.equal(0)
				expect(table.isfrozen(each)).to.equal(true)
			end
		end)

		it("puts the bead on the view axis, exactly, because that is where the bead is", function()
			-- THE WHOLE OF GEOMETRIC ADS, as algebra rather than as a screenshot. `aimOffset` is the
			-- offset from the camera to the gun's pivot; composing it with the sight's own CFrame
			-- must land the sight EYE_RELIEF_STUDS straight in front of the camera, looking where
			-- the camera looks. Zero tolerance beyond floating point: the 0.37-degree tolerance
			-- belongs to the screen, and this is the maths the screen rests on.
			local sight = CFrame.new(0, 0.255, -2.15) -- the parts gun's bead, Shape.beadOffset
			local aimed = Mode.aimOffset(sight, firstPerson) * sight
			expect((aimed.Position - Vector3.new(0, 0, -firstPerson.EYE_RELIEF_STUDS)).Magnitude < 1e-4).to.equal(true)
			-- ...AND THE GUN IS TIPPED BY EXACTLY THE CHEEK ANGLE (task 92, round 2), which is the
			-- other half of the claim: the bead does not move, everything behind it swings down, so
			-- the player looks along the TOP of the barrels as in Karen's own picture. The angle is
			-- measured off the pose rather than assumed, so a cheek angle that stopped being applied
			-- fails here rather than only on a screenshot.
			local tilt = math.deg(math.asin(math.clamp(aimed.LookVector.Y, -1, 1)))
			expect(math.abs(tilt - firstPerson.ADS_CHEEK_DEG) < 1e-3).to.equal(true)
			expect(math.abs(aimed.LookVector.X) < 1e-6).to.equal(true)

			-- ...and it FOLLOWS the bead: move the sight, and the gun moves to suit it. A pose that
			-- ignored its argument would pass the case above and fail this one.
			local moved = CFrame.new(0.3, 0.5, -2.0)
			local movedAimed = Mode.aimOffset(moved, firstPerson) * moved
			expect((movedAimed.Position - Vector3.new(0, 0, -firstPerson.EYE_RELIEF_STUDS)).Magnitude < 1e-4).to.equal(
				true
			)
			expect(Mode.aimOffset(moved, firstPerson)).never.to.equal(Mode.aimOffset(sight, firstPerson))

			-- AND THE CHEEK ANGLE IS A DIAL ON SOMETHING: at zero the gun is level with the view, so
			-- the case above is measuring the angle rather than an accident of the arithmetic.
			local level = table.clone(firstPerson) :: any
			level.ADS_CHEEK_DEG = 0
			local levelAimed = Mode.aimOffset(sight, level) * sight
			expect((levelAimed.LookVector - Vector3.new(0, 0, -1)).Magnitude < 1e-6).to.equal(true)
			expect((levelAimed.Position - Vector3.new(0, 0, -level.EYE_RELIEF_STUDS)).Magnitude < 1e-4).to.equal(true)
		end)

		it("falls back to the accepted framing when the gun carries no sight", function()
			-- A DECISION, NOT AN ACCIDENT (design section 9.1 item 6): an old Handle or a mesh whose
			-- row has no measurement yet still draws, at the framing Task 26/47 accepted, and
			-- `Viewmodel.stats().sightMissing` counts it.
			expect(Mode.aimOffset(nil, firstPerson)).to.equal(Config.VIEWMODEL_AIM_OFFSET)
			expect(Mode.aimOffset(nil, Config)).to.equal(Config.VIEWMODEL_AIM_OFFSET)
		end)

		it("returns the aimed pose bitwise at rest, which the screen measurement rests on", function()
			local sight = CFrame.new(Shape.beadOffset(Shotgun.CONFIG))
			expect(Mode.viewmodelOffset(stateAtBlend(1), sight, firstPerson)).to.equal(
				Mode.aimOffset(sight, firstPerson)
			)
			-- and the OFF branch keeps the pose Karen accepted for the shoulder camera: a sight
			-- changes nothing there, deliberately.
			expect(Mode.viewmodelOffset(stateAtBlend(1), sight, Config)).to.equal(Config.VIEWMODEL_AIM_OFFSET)
		end)

		it("aims at a point in first person too, which is what the harness stages a shot with", function()
			-- Camera.lookAt is how the harness stages shoot-the-boar, and it must land in both
			-- branches (design section 9.1 item 14). At the eye the iteration has almost nothing to
			-- correct, so one pass would do -- but the assertion is the result, not the count.
			local root = CFrame.new(0, 0, 0)
			local target = Vector3.new(6, 2, -20)
			local aimed = Mode.anglesToward(stateAtBlend(0), root, target, firstPerson)
			local _, desired = Mode.cameraCFrame(root, aimed, firstPerson)
			local to = (target - desired.Position).Unit
			expect(math.deg(math.acos(math.clamp(desired.LookVector:Dot(to), -1, 1))) < 0.01).to.equal(true)
		end)
	end)

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
			-- BUILT FROM `Mode.initial`, not written out field by field: since task 92 the camera's
			-- view pitch reads a cosmetic term (the recoil offset), and a hand-made state missing it
			-- fails with "arithmetic on nil" -- which is exactly the failure `Mode.step`'s "carried,
			-- not rebuilt" comment exists to avoid, one layer up, in a test.
			local naive = table.clone(Mode.initial(Config)) :: any
			naive.mode = "Third"
			naive.blend = 0
			naive.yawDeg = math.deg(math.atan2(-direction.X, -direction.Z))
			naive.pitchDeg = math.deg(math.asin(direction.Y))
			naive.sinceModeChange = 0
			table.freeze(naive)
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
