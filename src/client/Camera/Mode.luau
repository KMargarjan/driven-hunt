--!strict
-- Camera.Mode: the camera's whole state machine AND all of its maths, pure. No Instances, no
-- services, no clock, no Players -- `dt`, `lookDelta` and `config` are parameters. That is what lets
-- tests/server/camera_mode.spec.luau drive 10,000 steps on the SERVER with no client, no player and
-- no camera, the way tests/server/boar_brain.spec.luau drives the boar's brain with no world.
--
-- Pattern: reducer over a frozen state, `(state, input, dt, config) -> state`, as Boar.Brain and
-- Weapon.StateMachine already are in this repo (rule 2 applies to internal patterns too).
--   Frame-rate-independent blending: the blend advances by dt / AIM_BLEND_SECONDS, so it reaches
--   exactly 1 after that many seconds of accumulated dt at ANY frame rate -- not an exponential
--   approach that never arrives (Rory Driscoll, "Frame rate independent damping using lerp",
--   https://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/).
--   Quad/Out easing, written out as 1-(1-t)^2, so this module needs no TweenService.
--   https://create.roblox.com/docs/reference/engine/classes/Camera  -- CFrame and FieldOfView
--
-- Design: docs/design/camera.md (sections 4, 5.2, 8.1)
-- Note:   docs/research/2026-09-24-shotgun.md (sources 4-5)
local Mode = {}

export type ModeName = "Loading" | "Third" | "Aiming" | "Dead"

export type State = {
	mode: ModeName,
	blend: number,
	yawDeg: number,
	pitchDeg: number,
	sinceModeChange: number,
	-- THE COSMETIC TERMS (design section 5.2). Task 89 (S1) puts them in the state and composes
	-- them in `viewmodelOffset`; NOTHING MOVES THEM YET -- sway and bob have no maths here, and the
	-- recoil springs and the break-open tilt arrive with S4. They are declared now, at their exact
	-- rests, for one reason: the composition order is the bug in every viewmodel, so it is written
	-- and tested once, while every term is identity, rather than assembled later under a feel change.
	-- `swayDeg` is degrees on screen, `bobStuds` a camera-space displacement, `openTilt` a 0..1 blend.
	swayDeg: Vector2,
	bobPhase: number,
	bobStuds: Vector3,
	recoilGunPitchDeg: number,
	recoilGunPitchRate: number,
	recoilGunBackStuds: number,
	recoilGunBackRate: number,
	recoilCamPitchDeg: number,
	recoilCamPitchRate: number,
	openTilt: number,
}

export type StepInput = {
	aiming: boolean,
	alive: boolean,
	hasCharacter: boolean,
	lookDelta: Vector2,
}

-- (-180, 180]. Without this, yaw drifts without bound over a session.
local function wrapDeg(deg: number): number
	local wrapped = (deg + 180) % 360 - 180
	return if wrapped <= -180 then wrapped + 360 else wrapped
end

-- The exact rest of every cosmetic term, in one place, so "at rest" is a value and not an opinion
-- (design section 4.5). Task 89 never leaves it.
local function atRest()
	return {
		swayDeg = Vector2.zero,
		bobPhase = 0,
		bobStuds = Vector3.zero,
		recoilGunPitchDeg = 0,
		recoilGunPitchRate = 0,
		recoilGunBackStuds = 0,
		recoilGunBackRate = 0,
		recoilCamPitchDeg = 0,
		recoilCamPitchRate = 0,
		openTilt = 0,
	}
end

function Mode.initial(config): State
	local state = atRest()
	state.mode = "Loading" :: ModeName
	state.blend = 0
	state.yawDeg = 0
	state.pitchDeg = config.SPAWN_PITCH_DEG
	state.sinceModeChange = 0
	return table.freeze(state)
end

-- Quad/Out. One site, so "the ease" is a thing with a name rather than a formula repeated twice.
function Mode.ease(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return 1 - (1 - clamped) * (1 - clamped)
end

-- THE ONE conversion from a field of view to a mouse-sensitivity scale (design section 8.1):
-- tan(fov/2) / tan(fovThird/2) keeps degrees-per-pixel constant ON SCREEN across the zoom, so the
-- sensitivity eases exactly in step with the FOV instead of snapping at a threshold.
function Mode.sensitivityScale(fovDeg: number, config): number
	if config.AIM_SENSITIVITY_OVERRIDE then
		return config.AIM_SENSITIVITY_OVERRIDE
	end
	return math.tan(math.rad(fovDeg) / 2) / math.tan(math.rad(config.FOV_THIRD_DEG) / 2)
end

-- HOW LONG THE MOVE TAKES, up and down (task 95). One question, one site: first person raises the
-- gun in `AIM_RAISE_SECONDS` and drops it in `AIM_LOWER_SECONDS` -- the reference clip's own
-- quarter-second swing -- while the third-person branch keeps the single `AIM_BLEND_SECONDS` it has
-- had since task 26, which is the camera Karen accepted and task 89 promised not to touch.
function Mode.blendSeconds(config, aiming: boolean): number
	if not config.FIRST_PERSON then
		return config.AIM_BLEND_SECONDS
	end
	return if aiming then config.AIM_RAISE_SECONDS else config.AIM_LOWER_SECONDS
end

-- The blended field of view for a blend value, eased.
local function fovFor(blend: number, config): number
	local eased = Mode.ease(blend)
	return config.FOV_THIRD_DEG + (config.FOV_AIM_DEG - config.FOV_THIRD_DEG) * eased
end

Mode.fovFor = fovFor

-- The next mode, given what the world looks like this frame (design section 4.2).
local function nextMode(state: State, input: StepInput): ModeName
	if not input.hasCharacter then
		return "Loading"
	end
	if not input.alive then
		return "Dead"
	end
	if state.mode == "Loading" or state.mode == "Dead" then
		-- A character that is present and alive leaves Loading/Dead for Third; aim is not honoured
		-- on the same frame, so a held aim button cannot skip the third-person frame on respawn.
		return "Third"
	end
	return if input.aiming then "Aiming" else "Third"
end

-- ------------------------------------------------------------------ recoil (task 92)
-- Karen, after playing S2 (2026-09-27): "shooting has to have recoil a bit".
--
-- ONE SPRING, THREE TERMS. Each of the gun's pitch, the gun's travel back and the camera's pitch is a
-- damped harmonic oscillator about ZERO: the shot adds an offset, the spring takes it home. The
-- integrator is semi-implicit Euler -- velocity from the acceleration first, then position from the
-- new velocity -- which is the stable order for a spring and the one Roblox's own documentation uses
-- for spring-driven cameras.
--   Critically damped: c = 2 * zeta * omega with zeta = 1, so there is NO overshoot and no wobble.
--   Erin Catto, "Soft Constraints" (GDC 2011), the standard stiffness/damping form:
--   https://box2d.org/files/ErinCatto_SoftConstraints_GDC2011.pdf
--
-- WHY THE CAMERA TERM IS SEPARATE FROM `pitchDeg`: the player's own aim must not move. `pitchDeg` is
-- where they are looking and the shot ray comes from it; `recoilCamPitchDeg` is added on top, for the
-- view only, and decays to EXACTLY zero (see `RECOIL_REST_EPSILON`) -- so the bead comes back to the
-- point it left rather than somewhere near it, which is what the spec asserts.
local function springStep(value: number, rate: number, dt: number, config): (number, number)
	if value == 0 and rate == 0 then
		return 0, 0 -- the common case: no shot has been fired, and no arithmetic is done
	end
	local omega = 2 * math.pi * config.RECOIL_FREQUENCY_HZ
	-- SUB-STEPPED, AND IT IS NOT A REFINEMENT. MEASURED: at 20 fps one Euler step of this spring is
	-- omega * dt = 1.13, past the point where semi-implicit Euler still damps -- the first run of
	-- `camera_mode.spec` had it still moving after a whole second, because the integrator was ringing
	-- rather than the spring. Splitting the frame into steps no longer than RECOIL_MAX_SUBSTEP_SECONDS
	-- makes the SPRING the thing that decides the settle, at any frame rate a player will ever see,
	-- which is what the 240/60/20 fps case asserts.
	local steps = math.max(1, math.ceil(dt / config.RECOIL_MAX_SUBSTEP_SECONDS))
	local h = dt / steps
	local nextValue, nextRate = value, rate
	for _ = 1, steps do
		local acceleration = -(omega * omega) * nextValue - 2 * config.RECOIL_DAMPING_RATIO * omega * nextRate
		nextRate += acceleration * h
		nextValue += nextRate * h
	end
	if math.abs(nextValue) < config.RECOIL_REST_EPSILON and math.abs(nextRate) < config.RECOIL_REST_EPSILON then
		return 0, 0 -- SNAPPED, so "settled" is a value a spec can assert and not an asymptote
	end
	return nextValue, nextRate
end

-- THE SHOT'S KICK. Called by the camera owner when the LOCAL player's shot lands, once per shot, and
-- it is a reducer like everything else here: no clock, no Instance, a new frozen state.
--
-- FIRST PERSON ONLY, by parameter rather than by flag: task 89 and 90 promised the flag-off branch is
-- the shoulder camera Karen accepted on 2026-09-25, unchanged, and a kick is something a player sees.
-- `camera_mode.spec` drives both configs, so the OFF branch is tested at the same time.
--
-- The offsets ADD and are then clamped: two barrels a tenth of a second apart are two kicks, and the
-- ceiling is what keeps a doublet from throwing the view off the animal.
function Mode.kick(state: State, config): State
	if not config.FIRST_PERSON then
		return state
	end
	local next_ = table.clone(state) :: any
	next_.recoilGunPitchDeg = math.clamp(
		state.recoilGunPitchDeg + config.RECOIL_GUN_PITCH_DEG,
		-config.RECOIL_MAX_GUN_PITCH_DEG,
		config.RECOIL_MAX_GUN_PITCH_DEG
	)
	next_.recoilGunBackStuds = math.clamp(
		state.recoilGunBackStuds + config.RECOIL_GUN_BACK_STUDS,
		-config.RECOIL_MAX_GUN_BACK_STUDS,
		config.RECOIL_MAX_GUN_BACK_STUDS
	)
	next_.recoilCamPitchDeg = math.clamp(
		state.recoilCamPitchDeg + config.RECOIL_CAM_PITCH_DEG,
		-config.RECOIL_MAX_CAM_PITCH_DEG,
		config.RECOIL_MAX_CAM_PITCH_DEG
	)
	return table.freeze(next_)
end

-- Is anything still moving? So a spec -- and the owner's own stats -- can say "settled" without
-- reading six fields, and so `Mode.step` can skip the springs entirely on the frames between shots.
function Mode.recoiling(state: State): boolean
	return state.recoilGunPitchDeg ~= 0
		or state.recoilGunPitchRate ~= 0
		or state.recoilGunBackStuds ~= 0
		or state.recoilGunBackRate ~= 0
		or state.recoilCamPitchDeg ~= 0
		or state.recoilCamPitchRate ~= 0
end

-- Returns a NEW frozen state. The caller holding the result is the only mutation in the system.
function Mode.step(state: State, input: StepInput, dt: number, config): State
	local mode = nextMode(state, input)

	-- Look first: the sensitivity depends on the CURRENT blended FOV, so a player turning while the
	-- zoom eases gets a continuous rate rather than a step at the threshold.
	local scale = Mode.sensitivityScale(fovFor(state.blend, config), config)
	local yaw = state.yawDeg
	local pitch = state.pitchDeg
	-- No look input while Loading OR Dead (design section 4.1: Dead is "no orbit, no input"). Round
	-- 1, finding 4: only Loading was suppressed, so a dead player could still swing the view.
	if mode ~= "Loading" and mode ~= "Dead" then
		yaw = wrapDeg(yaw - input.lookDelta.X * config.SENSITIVITY_DEG_PER_PIXEL * scale)
		pitch = math.clamp(
			pitch - input.lookDelta.Y * config.SENSITIVITY_DEG_PER_PIXEL * scale,
			config.PITCH_MIN_DEG,
			config.PITCH_MAX_DEG
		)
	end

	-- On the way back from Loading or Dead, pitch resets and yaw is KEPT: a respawn should not spin
	-- the player round, but it should not leave them staring at the sky either.
	if mode == "Third" and (state.mode == "Loading" or state.mode == "Dead") then
		pitch = config.SPAWN_PITCH_DEG
	end

	local seconds = Mode.blendSeconds(config, mode == "Aiming")
	local step = if seconds > 0 then dt / seconds else 1
	local blend = state.blend
	if mode == "Aiming" then
		blend = math.min(1, blend + step)
	else
		blend = math.max(0, blend - step)
	end

	-- CARRIED, NOT REBUILT. Every cosmetic term is copied from the state it arrived in: this
	-- reducer does not move any of them yet (S4 does), and a field silently dropped here would be
	-- `nil` in the next frame's composition rather than a visible failure.
	local next_ = table.clone(state) :: any
	next_.mode = mode
	next_.blend = blend
	-- THE RECOIL SPRINGS ARE THE ONE COSMETIC TERM THIS REDUCER MOVES (task 92). Sway, bob and the
	-- break-open tilt are still carried untouched, exactly as S1 left them.
	next_.recoilGunPitchDeg, next_.recoilGunPitchRate =
		springStep(state.recoilGunPitchDeg, state.recoilGunPitchRate, dt, config)
	next_.recoilGunBackStuds, next_.recoilGunBackRate =
		springStep(state.recoilGunBackStuds, state.recoilGunBackRate, dt, config)
	next_.recoilCamPitchDeg, next_.recoilCamPitchRate =
		springStep(state.recoilCamPitchDeg, state.recoilCamPitchRate, dt, config)
	next_.yawDeg = yaw
	next_.pitchDeg = pitch
	next_.sinceModeChange = if mode == state.mode then state.sinceModeChange + dt else 0
	return table.freeze(next_)
end

-- (pivot, desired camera CFrame, fov). Pure geometry: no raycast, no Instance. The two angles are
-- converted to radians HERE and nowhere else.
function Mode.cameraCFrame(rootCFrame: CFrame, state: State, config): (Vector3, CFrame, number)
	local eased = Mode.ease(state.blend)
	local pivot = rootCFrame.Position + Vector3.new(0, config.PIVOT_HEIGHT_STUDS, 0)
	-- THE VIEW PITCH IS THE PLAYER'S PITCH PLUS RECOIL, and the recoil term is not the player's aim
	-- (task 92): it decays to exactly zero, so the view returns to `pitchDeg` and the bead to the
	-- point it left. Clamped together, so a kick at the top of the look range cannot gimbal the camera.
	local viewPitch = math.clamp(state.pitchDeg + state.recoilCamPitchDeg, config.PITCH_MIN_DEG, config.PITCH_MAX_DEG)
	local look = CFrame.fromEulerAnglesYXZ(math.rad(viewPitch), math.rad(state.yawDeg), 0)

	-- FIRST PERSON (task 89): the eye, at every blend. There is no boom and no shoulder to ease
	-- between, so `blend` changes the field of view and the viewmodel's pose and moves the camera
	-- not at all -- which is why `AIM_PIVOT_FORWARD_STUDS` is applied always rather than eased in:
	-- the eye sits a little ahead of the pivot so it is never inside the character's own head.
	--
	-- AND THAT IS THE NO-JUMP RULE, WHICH IS NOW ASSERTED (task 92). Karen, after playing S2: "I
	-- expect when clicking mouse right the weapon height (aim dot) is in same level as before clicking
	-- mouse right." Pressing right mouse must move the GUN and nothing else: in this branch the eye's
	-- position and the look direction are independent of `blend` and of `eased`, so the world point
	-- under the screen centre is bit-for-bit the same before and after. `camera_mode.spec` drives
	-- blend 0 -> 1 and asserts exactly that, and the client spec measures the point in a live session.
	--
	-- Third person: back along the look direction, offset to the shoulder. Aiming: at the eye,
	-- slightly forward of the pivot. Everything in between is the eased mix of the two.
	local distance, shoulder, forward
	if config.FIRST_PERSON then
		distance, shoulder, forward = 0, Vector3.zero, config.AIM_PIVOT_FORWARD_STUDS
	else
		distance = config.THIRD_DISTANCE_STUDS * (1 - eased)
		shoulder = config.SHOULDER_STUDS * (1 - eased)
		forward = config.AIM_PIVOT_FORWARD_STUDS * eased
	end

	local offset = look:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, distance - forward))
	local position = pivot + offset

	-- The hard clamp. It keeps the fire origin inside the shotgun's CAMERA_ORIGIN_TOLERANCE of 30
	-- studs (docs/design/shotgun.md section 11) with 15 studs of headroom, so an honest shot is
	-- never rejected "origin-far" because the camera drifted.
	local fromRoot = position - rootCFrame.Position
	if fromRoot.Magnitude > config.MAX_DISTANCE_STUDS then
		position = rootCFrame.Position + fromRoot.Unit * config.MAX_DISTANCE_STUDS
	end

	return pivot, CFrame.lookAt(position, position + look.LookVector), fovFor(state.blend, config)
end

-- The yaw and pitch that point the CAMERA at `point`, for a character at `rootCFrame`.
--
-- Not one line of trigonometry, because the camera does not sit at the pivot: it sits a boom behind
-- it and over the right shoulder, and both of those move when the angles change. Aiming the PIVOT at
-- a target 20 studs away leaves the camera pointing about 6 degrees off -- wide enough to miss a
-- 2-stud boar. So this iterates: take the camera position the current angles produce, aim from
-- THERE, repeat. Each pass divides the error by about four -- MEASURED: aiming the pivot at a target
-- 20 studs away leaves the camera 3.97 degrees off, four passes leave 0.08 -- so it runs six, which
-- is still nothing (it happens once, when a shot is staged) and lands inside a hundredth of a degree.
-- It is pure, so tests/server/camera_mode.spec.luau checks it with no client at all.
--
-- Used by Camera.lookAt, which the harness invokes to stage a scenario on a target
-- (tools/studio_mcp.py, the `stage` step), and by nothing else today.
function Mode.anglesToward(state: State, rootCFrame: CFrame, point: Vector3, config): State
	local result = state
	for _ = 1, 6 do
		local _, desired = Mode.cameraCFrame(rootCFrame, result, config)
		local to = point - desired.Position
		if to.Magnitude < 1e-3 then
			break -- the target is where the camera already is; leave the angles alone
		end
		local direction = to.Unit
		-- The inverse of cameraCFrame's own convention: LookVector is
		-- (-sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch)).
		local pitch =
			math.clamp(math.deg(math.asin(math.clamp(direction.Y, -1, 1))), config.PITCH_MIN_DEG, config.PITCH_MAX_DEG)
		local yaw = wrapDeg(math.deg(math.atan2(-direction.X, -direction.Z)))
		-- Cloned rather than rebuilt field by field, for the reason `Mode.step` gives: this
		-- function changes exactly two numbers, and listing the other fourteen is how one goes
		-- missing.
		local next_ = table.clone(result) :: any
		next_.yawDeg = yaw
		next_.pitchDeg = pitch
		result = table.freeze(next_)
	end
	return result
end

-- THE CARRY POSE (task 89, first person only): the gun held low and LEFT while walking. Position
-- plus three named degrees, and this is the ONE site that converts them -- the rule introduced after
-- the Task 19 cone-unit defect, where a 2x error hid in a second conversion.
function Mode.carryOffset(config): CFrame
	return CFrame.new(config.VIEWMODEL_CARRY_POS_STUDS)
		* CFrame.Angles(
			math.rad(config.CARRY_PITCH_DEG),
			math.rad(config.CARRY_YAW_DEG),
			math.rad(config.CARRY_ROLL_DEG)
		)
end

-- THE AIMED POSE, AND IT IS GEOMETRY RATHER THAN A NUMBER SOMEBODY LIKED (task 90, S2).
--
-- Aiming must put the gun's own bead on the camera's axis, `EYE_RELIEF_STUDS` in front of the eye,
-- pointing where the camera points. The viewmodel's pivot is the cloned `Handle`, and `sightLocal`
-- is where the `Sight` attachment sits in that Handle's frame, so:
--
--   handleWanted = camCFrame * CFrame.new(0, 0, -EYE_RELIEF) * sightLocal:Inverse()
--   => the offset from the camera is  CFrame.new(0, 0, -EYE_RELIEF) * sightLocal:Inverse()
--
-- and the bead lands on the axis BECAUSE OF WHERE THE BEAD IS. Move the bead, and the gun moves to
-- suit it; swap the parts gun for the mesh, and the pose follows the new measurement. Nothing here
-- is tuned by eye.
--
-- `sightLocal == nil` is a gun that carries no `Sight` -- an old Handle, or a mesh whose row has no
-- measurement yet. It falls back to `VIEWMODEL_AIM_OFFSET`, the framing Task 26/47 accepted, and
-- `Viewmodel.stats().sightMissing` counts it so the fallback is visible rather than silent.
function Mode.aimOffset(sightLocal: CFrame?, config): CFrame
	if sightLocal == nil then
		return config.VIEWMODEL_AIM_OFFSET
	end
	-- THE CHEEK ANGLE IS APPLIED AT THE BEAD, which is the whole reason it is safe (task 92, round
	-- 2): a rotation about the point the bead sits at leaves the bead exactly where it was -- on the
	-- axis, `EYE_RELIEF_STUDS` ahead -- and swings only what is BEHIND it. That is what an eye above
	-- the bore actually sees: the top of the barrel running away to the bead, the action low in the
	-- frame. `camera_mode.spec` asserts both halves, the bead's position and the gun's new tilt.
	return CFrame.new(0, 0, -config.EYE_RELIEF_STUDS)
		* CFrame.Angles(math.rad(config.ADS_CHEEK_DEG), 0, 0)
		* sightLocal:Inverse()
end

-- Where the viewmodel sits, relative to the camera. The POSE is the eased mix of the hip/carry pose
-- and the aimed one; everything else in this function is cosmetic and, in task 90, exactly identity.
--
-- THE COMPOSITION ORDER IS THE BUG IN EVERY VIEWMODEL, so it is written once, here, and asserted
-- while every term is identity (design section 5.2):
--   * sway and bob PRE-multiply, in camera space: they move the gun ACROSS the frame;
--   * recoil and the break-open tilt POST-multiply, in gun space: the gun turns about its own grip.
-- With the state at rest the four cosmetic factors are exactly identity, so this returns the pose
-- bit for bit -- which is what `tests/server/camera_mode.spec.luau` asserts, and what the bead
-- measurement in S2 will rest on.
function Mode.viewmodelOffset(state: State, sightLocal: CFrame?, config): CFrame
	local hip = if config.FIRST_PERSON then Mode.carryOffset(config) else config.VIEWMODEL_HIP_OFFSET
	-- THE THIRD-PERSON BRANCH KEEPS ITS OWN AIMED POSE, deliberately: `VIEWMODEL_AIM_OFFSET` is what
	-- Karen accepted for the shoulder camera on 2026-09-25, and task 90 is not allowed to change
	-- what the OFF branch looks like. Geometric ADS is the first-person sight picture.
	local aim = if config.FIRST_PERSON then Mode.aimOffset(sightLocal, config) else config.VIEWMODEL_AIM_OFFSET
	local pose = hip:Lerp(aim, Mode.ease(state.blend))
	return CFrame.new(state.bobStuds)
		* CFrame.Angles(math.rad(state.swayDeg.Y), math.rad(state.swayDeg.X), 0)
		* pose
		* CFrame.new(0, 0, state.recoilGunBackStuds)
		* CFrame.Angles(math.rad(state.recoilGunPitchDeg + state.openTilt * config.OPEN_TILT_DEG), 0, 0)
end

return Mode
