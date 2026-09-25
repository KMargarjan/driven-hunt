--!strict
-- Camera.Config: every number this system has, frozen, with NO writer (CLAUDE.md rule 3).
--
-- Flat on purpose: scalars, Vector3 and CFrame, no nested tables. table.freeze is SHALLOW, so a flat
-- table is the only one whose freeze means what the word says (Task 23a note (b) caught exactly that
-- in the shotgun). Every angle is in DEGREES and says so in its name; each is converted to radians at
-- ONE named site -- the rule the shotgun design introduced after the Task 19 cone-unit defect.
--
-- Nothing is on disk as JSON: half of these are Vector3/CFrame, which the harness fails as "cannot
-- compare" until audit-002 must-fix 1 lands (TASKS.md row 16). Third system to make that choice,
-- after TestArena.LAYOUT and Boar.CONFIG.
--
-- Design: docs/design/camera.md (section 8)
-- Note:   docs/research/2026-09-24-shotgun.md (sources 4-5)
local Config = {
	-- field of view
	FOV_THIRD_DEG = 70, -- the engine default; keeps the stock look
	FOV_AIM_DEG = 50, -- feel (Karen): 1.4x magnification, a bead sight and not a scope
	AIM_BLEND_SECONDS = 0.20, -- feel; the research note says plainly this is not derived

	-- third-person framing
	THIRD_DISTANCE_STUDS = 12.0,
	SHOULDER_STUDS = Vector3.new(2.2, 0.35, 0), -- camera space, RIGHT shoulder
	PIVOT_HEIGHT_STUDS = 1.6, -- above HumanoidRootPart, about eye height
	AIM_PIVOT_FORWARD_STUDS = 0.4, -- so the aim camera is not inside the head

	-- looking
	PITCH_MIN_DEG = -72,
	PITCH_MAX_DEG = 78, -- short of +-90, so the camera never gimbals
	SENSITIVITY_DEG_PER_PIXEL = 0.25, -- feel (Karen). Converted once, in Mode.step
	AIM_SENSITIVITY_OVERRIDE = nil :: number?, -- nil = derive it from the FOV (Mode.sensitivityScale)
	SPAWN_PITCH_DEG = -8, -- yaw is KEPT across a respawn; only pitch resets

	-- the hard clamp that keeps the fire origin inside the shotgun's validator
	-- (docs/design/shotgun.md section 11: CAMERA_ORIGIN_TOLERANCE = 30 studs)
	MAX_DISTANCE_STUDS = 14.5,

	-- occlusion, one ray per frame
	OCCLUSION_MIN_DISTANCE_STUDS = 1.2, -- below it the camera is inside the character
	OCCLUSION_PAD_STUDS = 0.5, -- pull in short of the surface the ray found

	-- the viewmodel
	VIEWMODEL_HIP_OFFSET = CFrame.new(0.9, -0.9, -1.2), -- blend 0: low and right, mostly off-screen
	VIEWMODEL_AIM_OFFSET = CFrame.new(0, -0.22, -0.9), -- blend 1: barrel under the view line
	VIEWMODEL_SHOW_BLEND = 0.02, -- below it the viewmodel is UNPARENTED, not merely invisible
	BODY_HIDE_BLEND = 0.60, -- above it the local body gets LocalTransparencyModifier = 1

	-- names and switches
	RENDER_STEP_NAME = "DrivenHunt.Camera", -- the reserved prefix; grep finds every binding we own
	CURSOR_LOCKED_DEFAULT = true, -- MouseBehavior = LockCenter when no requestFree tag is out
	FREE_CURSOR_ON_DEATH = false, -- v1 has no death UI; the hook exists
}

return table.freeze(Config)
