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
-- THE POSE DATA (task 98). `Viewmodel.view` turns `src/shared/Viewmodel/poses.json` into the
-- flat names this file has always published, which is why there is still exactly one writer of
-- every pose number and it is that file. See the block above the merge at the bottom.
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))

local Config = {
	-- THE SWITCH (task 89, S1). ON: the eye, the carry pose below, no crosshair, no occlusion cast.
	-- OFF: everything this file said before, unchanged.
	FIRST_PERSON = Flags.isOn("FIRST_PERSON"),
	-- THE SECOND SWITCH (task 99), read at the same ONE boundary and passed inward as `config`.
	-- ON: the first-person gun is built from `ReplicatedStorage.Gun`'s exact pieces and poses
	-- from `poses.json`'s `newGun` set. OFF: the Tool's Handle, cloned, exactly as before -- and
	-- that is what every OTHER player sees in both cases, because the world gun is not in scope.
	NEW_GUN = Flags.isOn("NEW_GUN"),

	-- field of view
	FOV_THIRD_DEG = 70, -- the engine default; keeps the stock look
	FOV_AIM_DEG = 50, -- feel (Karen): 1.4x magnification, a bead sight and not a scope
	AIM_BLEND_SECONDS = 0.20, -- feel; the research note says plainly this is not derived
	-- FIRST PERSON RAISES FASTER THAN IT LOWERS (task 95). The reference clip Karen chose does the
	-- whole move in about a quarter of a second -- one swing, not a drift -- and drops the gun a
	-- little quicker than it lifts it. The third-person branch keeps `AIM_BLEND_SECONDS` both ways,
	-- which is what task 89 promised about the camera Karen accepted on 2026-09-25.
	-- NOW DATA (task 98): `raise.raiseSeconds` and `raise.lowerSeconds` in
	-- src/shared/Viewmodel/poses.json, which is also where the swing's optional MID KEYFRAMES
	-- live (`raise.keyframes`, empty as seeded, which is this plain two-pose ease).

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
	-- TASK 95 PUTS IT WHERE THE REFERENCE PUTS IT, and the reference is a picture rather than a
	-- sentence: `<assets-dir>/references/inspiration-2026-09-27/REF-SHEET-carry-aim.jpg`, panel A.
	-- The gun lies ACROSS THE LOWER LEFT -- the action just below the bottom edge left of centre, the
	-- barrels running away up-left and leaving the frame at the left edge, about a third of the gun
	-- on screen. It is a cradle carry, not a hip carry, and it is the pose in the clip Karen asked us
	-- to copy (2026-09-27).
	--
	-- SOLVED FROM TWO POINTS ON THE PICTURE, the way the aimed pose below is solved. In panel A the
	-- muzzle meets the LEFT EDGE about a third of the way up from the bottom, and the ACTION -- not
	-- the butt -- sits at the bottom edge, left of centre. In the carry's 70-degree field that is the
	-- muzzle at 40.6 degrees left (the edge) and 14 down, and the action at 12 left and 28 down, with
	-- the action about 1.45 studs out: a 2.73-stud barrel between those two points fixes the gun's
	-- direction, and the Handle's centre is 0.53 studs behind the action along it.
	--
	-- THEN MEASURED ON SCREEN AND MOVED TWICE, because the arithmetic above lands within about ten
	-- degrees of where the viewmodel actually renders: the solved pose put the barrel at 8 degrees
	-- and the action halfway up the frame, so the gun came down 0.22 studs, left 0.11, and its nose
	-- up 11. What ships reads at about 28 degrees with the muzzle meeting the left edge two thirds
	-- of the way down and the action at the bottom edge a third across -- panel A's own diagonal, and
	-- round 1's was 37. The STOCK is out of the picture either way, which is what the picture shows.
	-- A RECORD OF A MEASUREMENT, applied by nothing and asserted by nothing: what the carry pose
	-- read on screen when it was solved. Task 97 re-solved it from the new video at 45 degrees on
	-- 16:9, which is the pose task 98 seeded `poses.json` with; the live number moves whenever the
	-- Director tunes the pose, so this says WHEN it was measured rather than what is true now.
	CARRY_ON_SCREEN_DEG = 45, -- as seeded, 2026-10-01
	-- Three named degrees rather than a CFrame literal, so there are three legible dials. Converted
	-- to radians at ONE site, Mode.carryOffset -- the rule the Task 19 cone-unit defect bought.
	-- POSITIVE yaw turns the muzzle in toward the screen centre from a RIGHT-hand offset (task 90):
	-- with the gun's own -Z as the muzzle, +14 degrees about Y points it left of straight ahead, so
	-- the barrels cross the frame from the lower right toward the centre. Pitch lifts the muzzle,
	-- roll cants the rib toward the eye; both are mirrored from task 89's left-handed pose, which is
	-- what "mirror it" means for a rotation about Y and Z.
	-- THE DIRECTION THAT LINE POINTS, in the camera's own frame: 39 degrees of yaw swings the muzzle
	-- LEFT and 10 degrees of pitch lifts it, which is 40 degrees left and 8 up in world terms -- the
	-- barrel crossing the frame from the lower right of the action to the left edge, exactly panel
	-- A's diagonal, with the muzzle leaving the frame at the left edge rather than stopping inside
	-- it. `Mode.carryOffset` is still the ONE site that converts them to radians.
	-- NOW DATA (task 98): `carry.gun.pos` and `carry.gun.rot` in src/shared/Viewmodel/poses.json.
	-- `VIEWMODEL_CARRY_POS_STUDS`, `CARRY_PITCH_DEG`, `CARRY_YAW_DEG` and `CARRY_ROLL_DEG` are
	-- still published here, by `Viewmodel.view`, so every reader and every spec is unchanged.
	--
	-- WHAT THE SEEDED VALUES ARE AND WHERE THEY CAME FROM (task 97 round 2, commit 9393d1e --
	-- the Director's pick as closest to Karen's target): position (-0.67, -0.57, -1.22), pitch
	-- 23.9, yaw 45.7, roll -10. Solved from `TARGET-carry.jpg` in the 2026-10-01 reference video
	-- by three readings -- the action at the bottom edge 31 % across, the muzzle leaving the LEFT
	-- edge 40 % down, and the barrel pair about 8 % of the screen wide where it meets the bottom
	-- -- then re-solved once against what actually rendered. The derivation is kept in
	-- docs/research/2026-10-01-poses-as-data.md section 6; the VALUES are now tuned live.
	-- The whole-gun break-open tilt. IT IS IN THE COMPOSITION FROM S1 AND NOTHING MOVES IT UNTIL
	-- S4: `Mode.viewmodelOffset` multiplies by `openTilt * OPEN_TILT_DEG`, and `openTilt` is exactly
	-- 0 in every state this build produces. The number lives here now so the composition is written
	-- and tested once rather than assembled later under a feel change. A single MeshPart has no
	-- barrel to hinge (research note section 5.4), so the WHOLE gun tilts about its grip.
	OPEN_TILT_DEG = 22,

	-- ------------------------------------------------ the break-open reload (ON branch, task 96)
	-- KAREN, 2026-09-27: the reload is a BREAK ACTION, like the real Beretta 486 Parallelo -- the
	-- barrels hinge down off the action -- and NOT the reference game's pump-style muzzle-up reload.
	--
	-- NONE OF THIS TOUCHES THE RELOAD'S RULES OR ITS CLOCK. The server still owns break, load, load
	-- and close and their timings (`Shotgun.CONFIG.RELOAD_*`); the client's replica carries `open`,
	-- and everything here is the drawn motion that follows it.
	--
	-- WHERE THE HINGE IS, in the Handle's own frame: the knuckle at the bottom front of the action.
	-- The barrels are 0.62 of a 4.4-stud gun, so the breech face is 0.53 studs behind the Handle's
	-- centre, and the pin sits just under the bore line.
	-- NOW DATA (task 98): `reload.hingeStuds` and `reload.openDeg` in
	-- src/shared/Viewmodel/poses.json. Seeded with (0, -0.06, 0.50) and 35 degrees -- a crisp
	-- break, with the two chambers facing the player.
	-- WHERE THE GUN IS HELD WHILE IT IS OPEN, as a pose of its own rather than an offset on the
	-- carry: in front of the player, low, and turned so the breech faces the eye. MEASURED -- added
	-- to the carry, which already keeps the gun low and left with a third of it in frame, "down a
	-- little" put the whole gun outside the picture.
	-- NOW DATA (task 98): `reload.gun.pos` and `reload.gun.rot`, seeded with (-0.27, -0.40, -1.72)
	-- and pitch 8, yaw 30, roll -25.
	-- How long the drawn swing takes, each way. Both are shorter than the server's own break and
	-- close steps (0.35 s and 0.30 s), so the motion is always finished before the state that
	-- started it ends -- the gun is never caught half open when the shells arrive.
	-- NOW DATA (task 98): `reload.openSeconds` and `reload.closeSeconds`, seeded with 0.22 and
	-- 0.16. BOTH MUST STAY SHORTER than the server's own break and close steps, which is a rule
	-- about the game and not a taste: `tests/server/viewmodel_poses.spec.luau` asserts it against
	-- `Shotgun.CONFIG.RELOAD_*`, so tuning them past it fails the harness.

	-- THE SHELLS. Spent ones pop out of the barrels that fired; fresh ones slide in. Plain parts,
	-- drawn by the viewmodel for one player, never replicated: red plastic with a brass base.
	SHELL_SIZE_STUDS = Vector3.new(0.055, 0.055, 0.16),
	SHELL_BODY_COLOR = Color3.fromRGB(150, 32, 28),
	SHELL_BASE_COLOR = Color3.fromRGB(196, 158, 82),
	SHELL_BASE_FRACTION = 0.34, -- how much of the shell's length is brass
	-- NOW DATA (task 98): `reload.shells` in src/shared/Viewmodel/poses.json -- `ejectSeconds`
	-- 0.35 (up and back, then gone), `ejectRiseStuds` 0.18 (measured: at 0.45 the shell flew
	-- clear across the frame), `feedSeconds` 0.30 and `feedFromStuds` 0.40 (how far behind the
	-- chamber a fresh shell starts). The shells' SIZE and COLOURS stay here: they are the
	-- geometry and the material of a part, not a pose.
	-- ------------------------------------------------------ the hands (ON branch, task 93)
	-- KAREN ASKED FOR THEM TWICE (PLAYTEST.md, 2026-09-27): "right hand grip and left hand pipes
	-- like in real life", and again after S2. She made both gloves in her own Meshy account; the
	-- server publishes the templates and `Camera.Viewmodel` clones them under the camera. Nobody
	-- else sees them -- other players see the character's own arms, exactly as before.
	--
	-- THE POSE LIVES HERE AND NOT ON THE GUN, which is a deviation from docs/design/camera.md S3
	-- (it has `Hardware` write `GripHold` and `ForeHold` attachments beside `Sight`). The reason is
	-- that a hand is cosmetic, client-side and first-person only -- the same class as the drawn
	-- bead, the shells and the fill light, all of which are already numbers in this file -- while
	-- `Sight` is on the gun because the SHOT GEOMETRY depends on it and the server writes it. Two
	-- dials for one measurement is what putting half of this in the manifest would buy: the hand's
	-- position and its orientation are one thing, measured together on one screenshot.
	--
	-- IN THE GUN'S OWN FRAME, like `BREAK_HINGE_STUDS`: -Z is the muzzle, +X is right, +Y is up, and
	-- the Handle's centre is the origin. The gun's own landmarks, from `Weapon.Shape`: the muzzle at
	-- Z = -2.2, the breech face at +0.54, the trigger at +0.78, the forend's centre at (0, -0.035,
	-- -0.21) and the bore line at Y = +0.12.
	--
	-- THE HAND MODELS ARE A HAND PLUS A CUFF and their pivot is the middle of that whole thing, so
	-- the POSITION below is where the middle of the forearm goes, about a third of the model behind
	-- the palm. THESE ARE FIRST PICKS AND THE SCREENSHOT IS THE MEASUREMENT -- the same way the
	-- carry and the aim were found in tasks 90 and 95. What is derived rather than picked is the
	-- direction: the right hand's fingers run forward along the stock's wrist with the index on the
	-- trigger guard, and the left hand's run forward under the barrels.
	-- MEASURED ON SCREEN, ROUND 2 (rule 5). The first pick put the right hand's palm 0.19 studs out
	-- to the right of the stock and 0.16 below it -- beside the wood rather than round it -- which
	-- the arithmetic says and the break screenshot showed. The palm sits 0.45 studs along the
	-- fingers from the model's centre, so moving the centre in and up by that much moves the palm
	-- onto the wrist of the stock.
	-- NOW DATA (task 98), AND PER POSE: `carry.right`, `aim.right` and `reload.right` in
	-- src/shared/Viewmodel/poses.json. All three are seeded with the SAME numbers -- position
	-- (0.12, -0.12, 0.80), yaw 78, pitch 10, twist -15, from task 97 round 2 -- so the drawn gun
	-- is bit-for-bit what it was while the capability to move a hand between poses now exists.
	-- `HAND_RIGHT_*` still names the CARRY hand, which is what `Mode.rightHandOffset` answers.
	-- Three named degrees, converted to radians at ONE site (`Mode.handOffset`) -- the rule the
	-- Task 19 cone-unit defect bought. YAW swings the hand's long axis (wrist to fingertip)
	-- horizontally, PITCH lifts or drops it, TWIST turns the hand about that axis -- which is the
	-- one a hand actually has, and the one that decides whether the palm faces the wood or the sky.
	-- MEASURED ON SCREEN, ROUND 2, AND IT MOVED FURTHEST. In the first build the left hand sat at
	-- the bottom-left CORNER of the carry frame, clear of the barrels, and in the aimed view it was
	-- a fist beside the tubes rather than a hand under them. The cause is arithmetic rather than
	-- taste: at 75 degrees of yaw the palm -- 0.45 studs along the fingers from the model's centre
	-- -- drifts 0.12 studs to the LEFT of wherever the centre is put, and the barrel pair is only
	-- 0.18 studs wide. So the yaw comes in to 80 (the forearm still angles out to the left, which
	-- is what a left hand does) and the centre moves right and up by what the drift costs.
	-- NOW DATA (task 98), AND PER POSE: `carry.left`, `aim.left` and `reload.left`, all seeded
	-- with position (-0.02, -0.08, -0.85), yaw -80, pitch -4, twist 180 (task 97 round 2).
	-- NEGATIVE YAW for the left hand, because its model runs the other way: the right hand's
	-- fingertips are at its mesh +X and the left hand's at its -X (measured on each prepped model's
	-- own bounds). TWIST 180 is what turns the palm UP, so the barrels lie in it rather than on the
	-- back of the hand.
	--
	-- ALL OF THAT IS ABOUT THE v1 GLOVES AND THE TOP-LEVEL POSES, AND ONLY THOSE (task 106). Model B
	-- wears a different pair under `poses.json`'s `newGun` set, measured the same way and answering
	-- differently: its left glove is modelled PALM-UP already, so its twist is 0, not 180, and both
	-- yaws are the full quarter turn. `Camera.Viewmodel.handTemplate` is the one place that picks a
	-- pair, by `NEW_GUN`; `ServerStorage.Assets` keeps them under two keys so neither can supersede
	-- the other.

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
	--
	-- 3.27 SINCE TASK 95, AND THE TWO NUMBERS WERE SOLVED TOGETHER WITH `ADS_CHEEK_DEG`. Panel C of
	-- the reference sheet wants the barrels to run from the BOTTOM EDGE of the screen away to the
	-- bead, a quarter of the screen wide where they leave it, with the action out of the picture
	-- below. Those are two equations: the bore's rear end (2.73 studs behind the bead, the barrels
	-- being 0.62 of a 4.4-stud gun) must sit on the 25-degree cone that is the bottom of the aiming
	-- field, and it must be 0.61 studs from the eye, which is what makes a 0.17-stud barrel pair a
	-- quarter of a 59-degree horizontal field. R = 0.553 + 2.73 cos(t), 2.73 sin(t) = 0.258 gives
	-- t = 5.4 degrees and R = 3.27. At the old 3.5 and 5 the barrels stopped SHORT of the bottom edge
	-- and the action filled the space below them -- measured on screen, which is the only place that
	-- shows.
	-- NOW DATA (task 98): `aim.eyeReliefStuds`, seeded with 3.65 (task 97 round 2, commit
	-- 9393d1e). The 3.27 above was task 95's; 3.65 is what brings the stock's wrist, the top tang
	-- and the right hand's fingers in front of the camera, which is what `TARGET-aim.jpg` of the
	-- 2026-10-01 video contains. MEASURED THE HARD WAY in task 97: at 4.15 the glove's CUFF
	-- reached the lens and the aimed view carried a pale untextured blob across its lower left --
	-- the INSIDE of the glove, because a MeshPart renders both of its faces.
	-- THE CHEEK ON THE COMB (task 92, round 2). In Karen's own acceptance picture the eye is ABOVE
	-- the rib, not level with it: you look down the TOP of the barrel, which tapers away to the bead,
	-- and the action is a dark shape at the very bottom of the frame. Level with the rib -- which is
	-- what pure bead-on-axis geometry gives, because the bead is the only thing it is told about --
	-- put the standing breech in the lower CENTRE as a big bulbous shape.
	--
	-- IT IS A ROTATION ABOUT THE BEAD, so nothing about the sight picture's one hard claim changes:
	-- the bead stays exactly `EYE_RELIEF_STUDS` in front of the eye, on the axis, which is where the
	-- shot goes. Everything BEHIND the bead swings down by this angle, which is what an eye above the
	-- bore sees. Positive drops the breech; 7 degrees puts the action's top below the rib line at the
	-- distance the breech sits from the eye (about 2.2 studs, so 0.27 studs of drop).
	-- THE CHEEK ANGLE, SOLVED WITH `EYE_RELIEF_STUDS` ABOVE (task 95, panel C): it rotates the gun
	-- about the BEAD, so the sight line is untouched and everything behind the bead swings down --
	-- an eye above the bore. 5.4 degrees is what puts the barrels' rear end exactly on the bottom
	-- edge of the aiming field, which is where the picture has them leave the frame.
	-- NOW DATA (task 98): `aim.cheekDeg`, seeded with 1.2 (task 97 round 2). The cheek angle
	-- swings everything BEHIND the bead downward, and 5.4 degrees is a quarter of a stud of drop
	-- at the breech -- which is what pushed the action and the stock off the bottom of the frame.
	-- In the video you look very nearly ALONG the rib, which 1.2 degrees is.
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
	-- IT IS CONTENT-LANE DATA SINCE TASK 102, and the four `VIEWMODEL_FILL_*` names are published at
	-- the bottom of this file by `Viewmodel.view` out of `look.fill` in
	-- src/shared/Viewmodel/poses.json. The history that bought the numbers stays here, because it is
	-- what a tuner needs to read before moving them:
	--   * 1.4 was the first pick and blew the action out to near-white in the aimed view; 1.0 kept
	--     the barrels' highlight and the walnut.
	--   * 0.8, and MOVED FORWARD since task 97: the light had sat 0.9 studs BEHIND the gun's centre,
	--     i.e. inside the action and the stock, inches from the lens, and the stock's left flank
	--     rendered as a blown-out white patch. A lamp inside the lampshade.
	--   * 0.45 and 1.30 studs forward since task 102, and THIS one was measured: at 0.8 with the
	--     light 0.80 studs forward it sat right on the new short action's breech, and the aimed
	--     capture read the fences and top strap at (155, 161, 173) from an albedo of (118, 120, 122).
	--     What the light is for is the barrels and the wood ALONG the gun, not the furniture that is
	--     already nearest the eye.
	-- "It stays here and is not pose data" was true until the thing being tuned turned out to be the
	-- light rather than the colour; it is still not a POSE, which is why it is `look` and not `aim`.

	-- ------------------------------------------------------ the sleeve (task 99)
	-- KAREN, 2026-10-01: in the break-open frame the left cuff's OPEN END faces the camera as a big
	-- black disc. A hand model is a hand plus a short cuff and nothing behind it, so wherever the arm
	-- would continue there is a hole -- and the open end of a tube pointed at the lens is the one
	-- view that shows it.
	--
	-- A SLEEVE THAT RUNS OFF SCREEN is the fix that needs no new asset: an olive cylinder on the
	-- hand's own long axis, starting at the cuff and running back past the near plane, so the end is
	-- always behind the camera. It is drawn by `Camera.Viewmodel` with the hands, for one player.
	SLEEVE_LENGTH_STUDS = 1.6, -- far enough back that the end is behind the eye in every pose
	-- 2.6 FOR MODEL B, AND THE RELOAD FRAME IS WHY (task 106, rule 5). 1.6 is far enough while the
	-- glove is 1.27 studs long and sits close to the eye; Karen's new pair is 0.67, so the hand sits
	-- further out -- in the broken-open frame the left one is 1.6 studs away, riding the barrels, and
	-- a 1.6-stud sleeve ended exactly at the lens. "Far enough back that the end is behind the eye in
	-- EVERY pose" is the claim, and the open-gun pose is the one that tests it.
	-- `Camera.Viewmodel.sleeveLength` is the one place that picks between them.
	SLEEVE_LENGTH_NEW_GUN_STUDS = 2.6,
	-- 0.20, NOT 0.30, AND THE SCREENSHOT IS WHY (rule 5). At 0.30 the sleeve read as an olive LOG
	-- lying across the right half of the break-open frame: it is inches from the eye, so its
	-- apparent size is nothing like its real one. A forearm at this distance is a narrow band.
	SLEEVE_DIAMETER_STUDS = 0.20,
	SLEEVE_COLOR = Color3.fromRGB(62, 66, 48), -- the olive of the jacket cuff on Karen's gloves
	SLEEVE_MATERIAL = Enum.Material.Fabric,
	-- How far the sleeve's near end sits INSIDE the cuff, so there is never a seam between them.
	SLEEVE_OVERLAP_STUDS = 0.12,
	-- 0.30 FOR MODEL B (task 106). Karen's new gloves carry their OWN turned cuff, and that cuff has
	-- its own open end: in the broken-open frame it faced the camera as an olive disc beside the
	-- forend (`.screenshots/20261002T111802Z-pose-reload.png`), which is task 99's complaint coming
	-- back on a different model. 0.12 was measured against a 1.27-stud glove; on a 0.67-stud one the
	-- drawn sleeve has to start nearly half a hand in to be inside the model's own cuff rather than
	-- behind it. It must stay under half the hand's own X, or the near end comes out through the
	-- fingers -- `tests/server/gun.spec.luau` asserts that against the published glove.
	SLEEVE_OVERLAP_NEW_GUN_STUDS = 0.30,

	-- A FOREARM, NOT A PIPE (task 108, round 1). The Director, on the first `pose.py inspect` frame:
	-- both olive sleeves "are long straight tubes running up out of the frame like pipes -- far too
	-- thick and too long, they must read as forearms". So model B's sleeve is drawn as THREE cylinder
	-- segments of equal length, listed wrist -> elbow, instead of one, and three steps are enough to
	-- stop it reading as a pipe at an inch from the lens. The mean is 0.127 against the 0.20 one that
	-- was there, a third thinner, which is the other half of the note. WHICH WAY IT STEPS is the next
	-- block's subject, and it is not the anatomical one.
	--
	-- THE TOTAL LENGTH DOES NOT CHANGE, and that is deliberate rather than ignoring "too long": the
	-- claim the length exists for is absolute -- the far end must be BEHIND THE EYE in every pose, or
	-- its open end is a disc in the frame, which is task 99's complaint. What made it read as a pipe
	-- is the thickness and the dead-straight constant width, not the studs. `SLEEVE_LENGTH_NEW_GUN_STUDS`
	-- stays the total; each segment is a third of it.

	-- WHICH WAY THE ARM RUNS, IN THE CAMERA'S OWN FRAME (task 108, round 2). The Director, on the
	-- round-1 frames: in AIM "the left SLEEVE crosses the frame as a straight olive bar from the left
	-- edge to the barrels", in RELOAD "a sleeve runs as a straight bar in from the upper-left corner
	-- across the gun" -- "in the target the forearms run DOWN and BACK out of the bottom corners
	-- toward the shoulders; they never cross the picture horizontally or come down from the top".
	--
	-- SO THE FOREARM IS NO LONGER THE HAND'S OWN AXIS. Round 1 ran it back along -X of the pose frame,
	-- which is the wrist -- anatomically right and wrong on screen, because the hand's axis turns with
	-- the grip while the SHOULDER does not move: a yaw of 15 at the forend sends it out sideways. A
	-- shoulder is a fixed place relative to the EYE, so this is read in the camera's frame (+X right,
	-- +Y up, +Z behind the lens) and is the same vector in carry, aim and reload. Down and back, a
	-- little outboard: it leaves through the bottom corner on its own side in all three.
	SLEEVE_TO_LEFT_SHOULDER = Vector3.new(-0.42, -0.62, 0.66).Unit,
	SLEEVE_TO_RIGHT_SHOULDER = Vector3.new(0.42, -0.62, 0.66).Unit,

	-- IT NARROWS TOWARD THE ELBOW, WHICH IS THE WRONG WAY ROUND FOR AN ARM, AND THE FIRST FRAME IS
	-- WHY (`.screenshots/20261002T142154Z-inspect-aim-left-front.png`). The glove MODEL carries its
	-- own turned olive cuff, and that cuff has an open end: at 0.080 the drawn sleeve was thinner than
	-- the hole it exists to plug, so BOTH gloves showed an open ellipse at the wrist -- task 99's
	-- complaint, back on a thinner tube. The wrist segment is sized to the cuff's own opening and the
	-- two behind it recede, which at an inch from the lens is what the eye reads anyway.
	SLEEVE_TAPER_NEW_GUN_STUDS = { 0.150, 0.125, 0.105 },

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
	-- NOW DATA (task 98): `fire` in src/shared/Viewmodel/poses.json. `frequencyHz` 3.6 (omega =
	-- 2*pi*f = 22.6 rad/s, home in about a third of a second) and `dampingRatio` 1.0 -- exactly
	-- critical, the one value with no overshoot and no wobble.
	--
	-- THE KICK IS A SPRING AND NOT A KEYFRAME LIST, deliberately, and it is the one place task 98
	-- did not do what its brief said. A keyframed recoil would replace the critically-damped
	-- spring whose behaviour `tests/server/camera_mode.spec.luau` rests on -- no overshoot, the
	-- same settle at 240, 60 and 20 fps, and a return to EXACTLY the aim point -- and the brief's
	-- own rule is that today's behaviour is preserved. So the spring's amplitudes, its frequency,
	-- its damping and its ceilings are the data, which is every dial the feel has.
	-- THE KICK ITSELF, per shot. The gun rises and comes back (in its own frame, so it follows the
	-- pose), and the camera lifts a fraction of what the gun does -- a shotgun shoves the shoulder,
	-- it does not throw the head.
	-- `fire.gunPitchDeg` 4.0, `fire.gunBackStuds` 0.14, `fire.camPitchDeg` 1.1.
	-- A CEILING, because two barrels can be fired a tenth of a second apart and the offsets add.
	-- Without it a doublet would throw the view off the animal, which is not "a bit".
	-- `fire.maxGunPitchDeg` 7.0, `fire.maxGunBackStuds` 0.25, `fire.maxCamPitchDeg` 2.0.
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

-- EVERY POSE NUMBER, FROM `poses.json`, AND THIS IS THE WHOLE OF "ONE SOURCE" (task 98).
--
-- The rows above that say NOW DATA are gone from this file as literals; the NAMES they used to
-- define are written here instead, computed by `Viewmodel.view` out of
-- `src/shared/Viewmodel/poses.json`. So a pose number cannot be in two places and disagree:
-- there is one file, one function that reads it, and -- while a Studio session is being tuned --
-- `Camera.Poses`, which calls that same function on the same data with the live override applied.
--
-- IT ASSERTS rather than warning, because a name that is missing or doubled is not survivable:
-- `Mode.carryOffset` would hand `CFrame.new(nil)` to the engine and the gun would be drawn
-- nowhere, with the one line that said why lost in a Play console.
-- `tests/server/viewmodel_poses.spec.luau` checks the shape of the file itself, so this only
-- ever fires for a `view` that forgot a name or a literal that came back.
for key, value in pairs(Viewmodel.view(Viewmodel.DATA, Config.NEW_GUN)) do
	assert(Config[key] == nil, "Camera.Config already defines " .. key .. "; poses.json is the one source")
	Config[key] = value
end

return table.freeze(Config)
