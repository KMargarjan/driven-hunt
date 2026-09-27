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
-- SINCE TASK 89 IT READS ONE FLAG, and this is the first client production module in the repo to
-- read `Flags` at all. It is the ONE boundary read (CLAUDE.md, "Feature flags"): the value is
-- resolved once, here, and passed inward as `config` by every function that needs it -- which is why
-- both branches stay reachable by parameter while the flag itself sits at one of them
-- (docs/design/feature-flags.md section 13.3). On a client `Flags.isOn` reads the replicated
-- `ReplicatedStorage.Flags.State` attributes, published by `FlagsBoot` before any player exists; the
-- pathological case waits and falls back to the DEFAULTS with its own warning -- i.e. to the accepted
-- shoulder camera, loudly, which is the honest failure (design section 6.6).
--
-- Design: docs/design/camera.md (sections 6.6, 8)
-- Note:   docs/research/2026-09-24-shotgun.md (sources 4-5),
--         docs/research/2026-09-27-first-person-viewmodel.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Config = {
	-- THE SWITCH (task 89, S1). ON: the eye, the carry pose below, no crosshair, no occlusion cast.
	-- OFF: everything this file said before, unchanged.
	FIRST_PERSON = Flags.isOn("FIRST_PERSON"),

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
	-- Measured on screen, not derived: the Handle is 4.4 studs long and pivots at its CENTRE, so at
	-- the design's -0.9 the rear half sat behind the near plane and the barrel entered from the
	-- bottom-right corner. Pushed forward so the whole gun is in front of the camera and the barrel
	-- runs under the view line. Karen's dial (docs/design/camera.md section 8: "the screenshot and
	-- Karen decide it").
	VIEWMODEL_HIP_OFFSET = CFrame.new(1.2, -1.2, -2.8), -- blend 0: low and right, mostly off-screen
	VIEWMODEL_AIM_OFFSET = CFrame.new(0, -0.6, -3.4), -- blend 1: barrel under the view line
	VIEWMODEL_SHOW_BLEND = 0.02, -- below it the viewmodel is UNPARENTED, not merely invisible
	BODY_HIDE_BLEND = 0.60, -- above it the local body gets LocalTransparencyModifier = 1

	-- ------------------------------------------------------ first person (ON branch, task 89)
	-- LOW AND RIGHT, and roughly half the gun off the bottom-right corner. KAREN, 2026-09-27, after
	-- playing S1: "has to be from right to left, meaning right hand shooter and weapon holding with
	-- right hand grip and left hand pipes like in real life". Task 89 built the reference's own
	-- left-handed carry; this is the mirror of it -- the stock at the right shoulder, the barrels
	-- crossing toward the centre-left, which is where the left hand will hold them in S3.
	--
	-- THE Z IS BOUNDED, NOT CHOSEN: the gun is Shotgun.CONFIG.HANDLE_SIZE.Z = 4.4 studs long about
	-- its CENTRE, so anything nearer than -2.2 would put the butt behind the camera plane. -2.6
	-- leaves about half a stud once the three angles below are applied, and
	-- tests/server/camera_mode.spec.luau asserts every one of the gun box's eight corners against
	-- NEAR_PLANE_MARGIN_STUDS rather than trusting this sentence.
	VIEWMODEL_CARRY_POS_STUDS = Vector3.new(0.95, -1.45, -2.6),
	-- Three named degrees rather than a CFrame literal, so there are three legible dials. Converted
	-- to radians at ONE site, Mode.carryOffset -- the rule the Task 19 cone-unit defect bought.
	-- POSITIVE yaw turns the muzzle in toward the screen centre from a RIGHT-hand offset (task 90):
	-- with the gun's own -Z as the muzzle, +14 degrees about Y points it left of straight ahead, so
	-- the barrels cross the frame from the lower right toward the centre. Pitch lifts the muzzle,
	-- roll cants the rib toward the eye; both are mirrored from task 89's left-handed pose, which is
	-- what "mirror it" means for a rotation about Y and Z.
	CARRY_PITCH_DEG = -12,
	CARRY_YAW_DEG = 14,
	CARRY_ROLL_DEG = -8,
	-- The whole-gun break-open tilt. IT IS IN THE COMPOSITION FROM S1 AND NOTHING MOVES IT UNTIL
	-- S4: `Mode.viewmodelOffset` multiplies by `openTilt * OPEN_TILT_DEG`, and `openTilt` is exactly
	-- 0 in every state this build produces. The number lives here now so the composition is written
	-- and tested once rather than assembled later under a feel change. A single MeshPart has no
	-- barrel to hinge (research note section 5.4), so the WHOLE gun tilts about its grip.
	OPEN_TILT_DEG = 22,
	-- ------------------------------------------------------ the bead sight (ON branch, task 90)
	-- HOW FAR THE BEAD SITS FROM THE EYE when aiming. DERIVED, not guessed: task 26/47's accepted
	-- `VIEWMODEL_AIM_OFFSET.Z = -3.4` put the Handle's centre 3.4 studs out and the bead 2.15
	-- further (`Shape.beadOffset().Z` is -2.15 in the Handle's frame), so 5.55 -- rounded to 5.6,
	-- which is 0.05 studs and sub-pixel. Geometric ADS therefore starts from a framing a screenshot
	-- already accepted. It is about 1.7x the anatomical eye-to-bead distance, deliberately: it keeps
	-- the butt in front of the near plane, which the corner assertion in camera_mode.spec enforces.
	-- 5.0, NOT THE DESIGN'S FIRST PICK OF 5.6: Karen asked for the aimed view to be CLOSER
	-- ("like looking through pipes", 2026-09-27) and this is the one number that does it. 0.6 studs
	-- in is about 12% more gun across the frame. The FLOOR is about 4.6 -- below that the butt
	-- crosses the near plane and `camera_mode.spec`'s corner case fails -- so this keeps 0.65 studs
	-- of clearance in hand. Karen's dial, and the screenshot in reviews/task-90 is what she judges.
	EYE_RELIEF_STUDS = 5.0,
	-- HOW FAR OFF THE CENTRE OF THE SCREEN THE BEAD MAY BE, aimed and at rest. Roblox's field of
	-- view is VERTICAL, so at 1920x1080 and FOV 50 this is 8 pixels: 50/1080 = 0.0463 degrees per
	-- pixel. At 143 studs (40 m) it is 0.9 studs, against a boar 5.5 studs long and 3 tall. The
	-- CLIENT spec measures it in the real viewport and derives the pixels from the live viewport
	-- size, because a Studio Play window is much smaller than 1080 px and a fixed pixel count there
	-- would be a LOOSER angular claim -- a false pass.
	BEAD_CENTRE_TOLERANCE_DEG = 0.37,
	-- THE DRAWN BEAD. Karen, 2026-09-27: "we are missing front knob or how it calls where you aim
	-- and follow animal with that point". The parts gun has a real `Bead` piece; the uploaded mesh
	-- is exactly ONE MeshPart with a painted one that is too small to aim with, so the viewmodel
	-- draws its own at the `Sight` attachment when the clone has no `Bead` part of its own. Neon, so
	-- it reads under the canopy where the S1 screenshot was almost black. 0.055 studs at
	-- EYE_RELIEF_STUDS is about 0.56 degrees -- roughly 12 px at 1080p, a bead and not a blob.
	-- The colour is `Shotgun.CONFIG.LOOK.bead` written out (the camera does not require the weapon);
	-- camera_client.spec asserts the two still agree.
	BEAD_MARKER_STUDS = 0.055,
	BEAD_MARKER_COLOR = Color3.fromRGB(242, 238, 226),

	-- ASSERTED, NOT APPLIED: nothing clamps to this. The near plane is 0.1 studs and a 4.4-stud gun
	-- held at the eye clips through it if the pose is wrong, so the spec measures the corners.
	NEAR_PLANE_MARGIN_STUDS = 0.25,

	-- names and switches
	-- How close a RENDERED frame must be to a Camera.lookAt request before the owner counts it as
	-- landed (stats().lookAtLanded). DELIBERATELY LOOSER than what the spec that waits on it then
	-- asserts (0.999, about 2.5 degrees): this says "the request reached the screen", not "the aim is
	-- good", so the spec's own measurement of Workspace.CurrentCamera stays a real assertion and not
	-- a restatement of this one. 0.99 is about 8.1 degrees. Task 50.
	LOOK_AT_LANDED_DOT = 0.99,

	RENDER_STEP_NAME = "DrivenHunt.Camera", -- the reserved prefix; grep finds every binding we own
	CURSOR_LOCKED_DEFAULT = true, -- MouseBehavior = LockCenter when no requestFree tag is out
	FREE_CURSOR_ON_DEATH = false, -- v1 has no death UI; the hook exists
}

return table.freeze(Config)
