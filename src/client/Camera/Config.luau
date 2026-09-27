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
	-- CLOSER SINCE THE SECOND BUILD ROUND OF TASK 90: at -2.6 the gun read "small and far" against
	-- Karen's own picture, so it comes in to -2.1 (about a quarter bigger on screen), up a little and
	-- in a little -- which also leaves the bottom-right corner clear for the right hand in S3.
	--
	-- THE BUTT IS BEHIND THE EYE AT THIS DISTANCE, and that is the point rather than a problem: the
	-- gun is 4.4 studs long about its CENTRE, so anything nearer than -2.2 puts the stock behind the
	-- camera plane -- which is where a real one is, under the cheek and out of the view.
	-- tests/server/camera_mode.spec.luau asserts what actually matters, on the gun's own pieces: the
	-- BARRELS, the rib and the bead clear NEAR_PLANE_MARGIN_STUDS in both poses, so nothing a player
	-- aims with is ever sliced.
	VIEWMODEL_CARRY_POS_STUDS = Vector3.new(0.85, -1.3, -2.1),
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
	-- HOW FAR THE BEAD SITS FROM THE EYE when aiming. 3.5, AND IT IS MEASURED OFF KAREN'S OWN
	-- ACCEPTANCE PICTURE rather than chosen: `<assets-dir>/references/inspiration-2026-09-27/`,
	-- `ads-target-karen.jpg`, her words -- "something like here is aiming (red point on end) and
	-- looking more through pipes like in real life".
	--
	-- THE MEASUREMENT IS SCALE-FREE, so it survives her gun being a different gun. In her picture the
	-- barrel's apparent width where it leaves the BOTTOM of the frame is about 4.4x its width at the
	-- muzzle; apparent width goes as 1/distance, so her muzzle is 4.4x as far from the eye as the
	-- point where the barrel leaves the frame. That point is where the bore line drops half the
	-- vertical field below the sight line -- with the bead 0.375 studs above the bore on this mesh
	-- and a 50-degree field, 0.375/tan(25) = 0.80 studs -- so the muzzle wants to be 4.4 x 0.80 = 3.5.
	--
	-- THE FIRST BUILD ROUND HAD 5.0 (and the design's own first pick was 5.6, derived from task
	-- 26/47's accepted `VIEWMODEL_AIM_OFFSET`): that put the eye a whole gun behind the breech, so
	-- the wooden STOCK filled the lower half as a plank and the barrels were a small shape in the
	-- middle -- which is not the picture she sent. At 3.5 the eye sits just behind the breech, the
	-- two barrels and the rib fill the lower centre and converge on the bead, and the stock passes
	-- BEHIND the camera. Karen's dial still; the floor is now the barrels rather than the butt (see
	-- NEAR_PLANE_MARGIN_STUDS).
	EYE_RELIEF_STUDS = 3.5,
	-- HOW FAR OFF THE CENTRE OF THE SCREEN THE BEAD MAY BE, aimed and at rest. Roblox's field of
	-- view is VERTICAL, so at 1920x1080 and FOV 50 this is 8 pixels: 50/1080 = 0.0463 degrees per
	-- pixel. At 143 studs (40 m) it is 0.9 studs, against a boar 5.5 studs long and 3 tall. The
	-- CLIENT spec measures it in the real viewport and derives the pixels from the live viewport
	-- size, because a Studio Play window is much smaller than 1080 px and a fixed pixel count there
	-- would be a LOOSER angular claim -- a false pass.
	BEAD_CENTRE_TOLERANCE_DEG = 0.37,
	-- THE DRAWN BEAD. Karen, 2026-09-27: "we are missing front knob or how it calls where you aim
	-- and follow animal with that point". The parts gun has a real `Bead` piece; the uploaded mesh is
	-- exactly ONE MeshPart with a painted one too small to aim with, so the viewmodel draws its own at
	-- the `Sight` attachment when the clone has no `Bead` part of its own.
	--
	-- A METAL BEAD, NOT A RED DOT (task 92). Karen, after playing S2: "that red dot is not realistic,
	-- we need to improve what actually is on Beretta Parallelo". What a Beretta 486 Parallelo actually
	-- carries is a small BRASS BALL on the rib at the muzzle -- no glass, no electronics, no colour
	-- that is not metal -- so this is brass, `Enum.Material.Metal`, and smaller: 0.05 studs at
	-- EYE_RELIEF_STUDS = 3.5 is 0.82 degrees, about 13 px in a 784-px viewport at the aiming field of
	-- view. Brass reads warm against both sky and ground, which is why every classic side-by-side uses
	-- it; against a bright sky it goes dark rather than invisible, which is what a real one does too.
	--
	-- It is still NOT `Shotgun.CONFIG.LOOK.bead`: that is the off-white bead of the PARTS gun, a piece
	-- of the weapon other players see. This is the aiming mark the camera draws for one player. Two
	-- things, two owners -- so the client spec asserts this one is brass-coloured metal rather than
	-- asserting the two still agree.
	BEAD_MARKER_STUDS = 0.05,
	BEAD_MARKER_COLOR = Color3.fromRGB(198, 158, 82),
	BEAD_MARKER_MATERIAL = Enum.Material.Metal,

	-- ------------------------------------------------------ the viewmodel's own light (task 92)
	-- Karen, after playing S2: "Weapon color we need to improve and style now feels a bit broken, it
	-- has to be smooth and nice." In first person the gun is inches from the eye and lit by the SUN
	-- ALONE, so under any sky but a noon one it reads as a near-black silhouette -- which is what her
	-- "broken" is looking at. A real gun at the cheek catches light from everything around it.
	--
	-- So the viewmodel carries ONE PointLight of its own, parented to the clone (which is a child of
	-- workspace.CurrentCamera, so it lights the gun and nothing else the player can see): warm, weak
	-- and short-ranged, shadows off. It does not light the world -- range 6 studs from a point inside
	-- the camera -- and it costs one light.
	VIEWMODEL_FILL_BRIGHTNESS = 1.4,
	VIEWMODEL_FILL_RANGE_STUDS = 6,
	VIEWMODEL_FILL_COLOR = Color3.fromRGB(255, 244, 224),
	-- Where the light sits relative to the gun's own pivot: up and to the left of the breech, so the
	-- barrels and the rib catch a highlight along their length and the wood behind them is lifted out
	-- of black. Camera space would move with the pose; the gun's own frame does not.
	VIEWMODEL_FILL_OFFSET_STUDS = Vector3.new(-0.6, 0.8, 0.9),

	-- ------------------------------------------------------ recoil (task 92)
	-- Karen, after playing S2: "shooting has to have recoil a bit" -- "a bit" is the whole brief, so
	-- these are first picks and every one of them is a dial.
	--
	-- ONE SPRING SHAPE FOR ALL THREE TERMS, critically damped: an offset is applied the instant the
	-- shot lands and a damped spring takes it back to exactly zero. Critically damped means NO
	-- overshoot and no oscillation -- the gun does not wobble, it settles -- and zero is an attractor,
	-- so the bead returns to the aim point rather than near it. The integrator is semi-implicit Euler
	-- (velocity first, then position), which is stable at this frequency for any frame time a player
	-- will see; `tests/server/camera_mode.spec.luau` drives it at 240, 60 and 20 fps and asserts the
	-- same settle.
	RECOIL_FREQUENCY_HZ = 3.6, -- omega = 2*pi*f = 22.6 rad/s, so it is home in about a third of a second
	RECOIL_DAMPING_RATIO = 1.0, -- exactly critical: the one value with no overshoot and no wobble
	-- THE KICK ITSELF, per shot. The gun rises and comes back (in its own frame, so it follows the
	-- pose), and the camera lifts a fraction of what the gun does -- a shotgun shoves the shoulder,
	-- it does not throw the head.
	RECOIL_GUN_PITCH_DEG = 4.0,
	RECOIL_GUN_BACK_STUDS = 0.14,
	RECOIL_CAM_PITCH_DEG = 1.1,
	-- A CEILING, because two barrels can be fired a tenth of a second apart and the offsets add.
	-- Without it a doublet would throw the view off the animal, which is not "a bit".
	RECOIL_MAX_GUN_PITCH_DEG = 7.0,
	RECOIL_MAX_GUN_BACK_STUDS = 0.25,
	RECOIL_MAX_CAM_PITCH_DEG = 2.0,
	-- Below this the spring is snapped to exact zero, so "settled" is a value and not an asymptote --
	-- the spec can assert the aim point is bit-for-bit what it was before the shot.
	RECOIL_REST_EPSILON = 1e-4,
	-- The longest step the spring is integrated in one go. A 20-fps frame is 0.05 s and omega * dt is
	-- then 1.13, which semi-implicit Euler does not damp: MEASURED, in this task's first run, as a
	-- spring still moving a second after the shot. The frame is split into steps this long or shorter,
	-- so the settle is the spring's and not the frame rate's.
	RECOIL_MAX_SUBSTEP_SECONDS = 1 / 60,

	-- ASSERTED, NOT APPLIED: nothing clamps to this. The near plane is 0.1 studs and a 4.4-stud gun
	-- held at the eye clips through it if the pose is wrong, so the spec measures the corners -- OF
	-- THE BARRELS, THE RIB AND THE BEAD, in both poses. It used to measure the whole gun's box, and
	-- that rule forbids the very picture Karen accepted: a cheek weld puts the STOCK behind the eye.
	-- The spec asserts both halves now -- nothing you aim with is sliced, and when aiming the stock
	-- really is behind the camera -- so "the gun is not clipped" stayed a mechanical claim instead of
	-- becoming a looser one. Deviation from docs/design/camera.md section 9.1 item 8, recorded in
	-- TASKS.md row 90a for the Architect.
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
