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

function Mode.initial(config): State
	return table.freeze({
		mode = "Loading" :: ModeName,
		blend = 0,
		yawDeg = 0,
		pitchDeg = config.SPAWN_PITCH_DEG,
		sinceModeChange = 0,
	})
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

	local step = if config.AIM_BLEND_SECONDS > 0 then dt / config.AIM_BLEND_SECONDS else 1
	local blend = state.blend
	if mode == "Aiming" then
		blend = math.min(1, blend + step)
	else
		blend = math.max(0, blend - step)
	end

	return table.freeze({
		mode = mode,
		blend = blend,
		yawDeg = yaw,
		pitchDeg = pitch,
		sinceModeChange = if mode == state.mode then state.sinceModeChange + dt else 0,
	})
end

-- (pivot, desired camera CFrame, fov). Pure geometry: no raycast, no Instance. The two angles are
-- converted to radians HERE and nowhere else.
function Mode.cameraCFrame(rootCFrame: CFrame, state: State, config): (Vector3, CFrame, number)
	local eased = Mode.ease(state.blend)
	local pivot = rootCFrame.Position + Vector3.new(0, config.PIVOT_HEIGHT_STUDS, 0)
	local look = CFrame.fromEulerAnglesYXZ(math.rad(state.pitchDeg), math.rad(state.yawDeg), 0)

	-- Third person: back along the look direction, offset to the shoulder. Aiming: at the eye,
	-- slightly forward of the pivot. Everything in between is the eased mix of the two.
	local distance = config.THIRD_DISTANCE_STUDS * (1 - eased)
	local shoulder = config.SHOULDER_STUDS * (1 - eased)
	local forward = config.AIM_PIVOT_FORWARD_STUDS * eased

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

-- Where the viewmodel sits, relative to the camera, for a given EASED blend.
function Mode.viewmodelOffset(easedBlend: number, config): CFrame
	return config.VIEWMODEL_HIP_OFFSET:Lerp(config.VIEWMODEL_AIM_OFFSET, math.clamp(easedBlend, 0, 1))
end

return Mode
