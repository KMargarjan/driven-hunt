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
	-- FIRST PERSON RAISES FASTER THAN IT LOWERS (task 95). The reference clip Karen chose does the
	-- whole move in about a quarter of a second -- one swing, not a drift -- and drops the gun a
	-- little quicker than it lifts it. The third-person branch keeps `AIM_BLEND_SECONDS` both ways,
	-- which is what task 89 promised about the camera Karen accepted on 2026-09-25.
	AIM_RAISE_SECONDS = 0.25,
	AIM_LOWER_SECONDS = 0.20,

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
	-- TASK 97 REPLACES BOTH POSES, AND A NEW VIDEO REPLACES EVERY EARLIER REFERENCE. Karen,
	-- 2026-10-01, on what shipped: "weapon is shit, aiming is shit ... follow the video"
	-- (`<assets-dir>/references/inspiration-2026-10-01/`, `sxs-video.mp4` and the TARGET frames).
	--
	-- SOLVED FROM `TARGET-carry.jpg`, TWO POINTS AND A WIDTH, rather than nudged: in that frame the
	-- barrels run from the ACTION at the bottom edge 31 % across to the MUZZLE leaving the LEFT edge
	-- 40 % down, and the barrel pair is about 8 % of the screen wide where it meets the bottom. Those
	-- three readings are three equations. Turned into camera-space rays through this build's own
	-- carry field of view (70 degrees vertical on a 958x784 viewport), they put the breech 1.17 studs
	-- from the eye and the muzzle 3.44, which fixes the gun's direction and its distance; the
	-- Handle's centre is 0.54 studs behind the breech along it. The old pose read 28 degrees across
	-- the screen and this one reads 45 -- which is the whole of Karen's "too low, too flat, too
	-- small".
	-- THEN MEASURED ON SCREEN AND RE-SOLVED ONCE (rule 5): the first build of this pose rendered
	-- about 8 % of the screen height HIGHER than the arithmetic asked for -- the muzzle left the left
	-- edge at 32 % instead of 40 % and the action sat at 91 % instead of the bottom edge -- so the
	-- same three equations were solved again with the measured bias folded into the asked-for points.
	-- WHAT THE ANGLE COMES OUT AT DEPENDS ON THE VIEWPORT, and that is worth writing down: Roblox's
	-- field of view is VERTICAL, so the same composition reads 45 degrees on the reference's 16:9 and
	-- about 57 in the 1.24:1 Studio Play window the screenshots are taken in. The COMPOSITION is what
	-- is matched -- muzzle off the left edge 40 % down, action at the bottom edge a third across --
	-- because that is what the picture is.
	-- READ, NOT APPLIED AND NOT ASSERTED: nothing in the game or in a spec uses this. It is here as
	-- the one-line record of what the pose above measures on a 16:9 screen, because the number a
	-- screenshot shows depends on the viewport and the specs are written in the camera's own frame.
	CARRY_ON_SCREEN_DEG = 45,
	VIEWMODEL_CARRY_POS_STUDS = Vector3.new(-0.67, -0.57, -1.22),
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
	-- DERIVED FROM A MUZZLE DIRECTION, then MOVED: `-sin(yaw), cos(yaw) sin(pitch), -cos(yaw)
	-- cos(pitch)` is a barrel line for exactly one pair of angles, and the pair below is the line
	-- (-0.716, 0.283, -0.638) -- which is the re-solve, 5.5 degrees flatter than the first one the
	-- comment above describes, because the first build rendered 8 % of the screen height high. Roll
	-- is a pure cant about the bore -- it moves no end of the gun -- so it stays the free dial, and
	-- it is a little stronger than before so the rib and not the flat of the barrels faces the eye,
	-- as it does in the video.
	CARRY_PITCH_DEG = 23.9,
	CARRY_YAW_DEG = 45.7,
	CARRY_ROLL_DEG = -10,
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
	BREAK_HINGE_STUDS = Vector3.new(0, -0.06, 0.50),
	BREAK_OPEN_DEG = 35, -- a crisp break: the two chambers face the player
	-- WHERE THE GUN IS HELD WHILE IT IS OPEN, as a pose of its own rather than an offset on the
	-- carry: in front of the player, low, and turned so the breech faces the eye. MEASURED -- added
	-- to the carry, which already keeps the gun low and left with a third of it in frame, "down a
	-- little" put the whole gun outside the picture.
	BREAK_POSE_STUDS = Vector3.new(-0.27, -0.40, -1.72),
	BREAK_POSE_PITCH_DEG = 8,
	BREAK_POSE_YAW_DEG = 30,
	BREAK_POSE_ROLL_DEG = -25,
	-- How long the drawn swing takes, each way. Both are shorter than the server's own break and
	-- close steps (0.35 s and 0.30 s), so the motion is always finished before the state that
	-- started it ends -- the gun is never caught half open when the shells arrive.
	BREAK_OPEN_SECONDS = 0.22,
	BREAK_CLOSE_SECONDS = 0.16,

	-- THE SHELLS. Spent ones pop out of the barrels that fired; fresh ones slide in. Plain parts,
	-- drawn by the viewmodel for one player, never replicated: red plastic with a brass base.
	SHELL_SIZE_STUDS = Vector3.new(0.055, 0.055, 0.16),
	SHELL_BODY_COLOR = Color3.fromRGB(150, 32, 28),
	SHELL_BASE_COLOR = Color3.fromRGB(196, 158, 82),
	SHELL_BASE_FRACTION = 0.34, -- how much of the shell's length is brass
	SHELL_EJECT_SECONDS = 0.35, -- up and back, then gone
	SHELL_EJECT_RISE_STUDS = 0.18, -- measured: at 0.45 the shell flew clear across the frame
	SHELL_FEED_SECONDS = 0.30, -- fresh shells sliding into the chambers
	SHELL_FEED_FROM_STUDS = 0.40, -- how far behind the chamber they start
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
	-- FORWARD AND DOWN SINCE ROUND 2, by the 0.10 studs the clearance above needed: the palm is at
	-- the front of the grip rather than the middle of it, which is as far back as the hand can sit
	-- and still keep its own rear corner out of the lens at a sensible eye relief.
	HAND_RIGHT_POS_STUDS = Vector3.new(0.12, -0.16, 0.70),
	-- Three named degrees, converted to radians at ONE site (`Mode.handOffset`) -- the rule the
	-- Task 19 cone-unit defect bought. YAW swings the hand's long axis (wrist to fingertip)
	-- horizontally, PITCH lifts or drops it, TWIST turns the hand about that axis -- which is the
	-- one a hand actually has, and the one that decides whether the palm faces the wood or the sky.
	HAND_RIGHT_YAW_DEG = 78,
	HAND_RIGHT_PITCH_DEG = 10,
	HAND_RIGHT_TWIST_DEG = -15,
	-- MEASURED ON SCREEN, ROUND 2, AND IT MOVED FURTHEST. In the first build the left hand sat at
	-- the bottom-left CORNER of the carry frame, clear of the barrels, and in the aimed view it was
	-- a fist beside the tubes rather than a hand under them. The cause is arithmetic rather than
	-- taste: at 75 degrees of yaw the palm -- 0.45 studs along the fingers from the model's centre
	-- -- drifts 0.12 studs to the LEFT of wherever the centre is put, and the barrel pair is only
	-- 0.18 studs wide. So the yaw comes in to 80 (the forearm still angles out to the left, which
	-- is what a left hand does) and the centre moves right and up by what the drift costs.
	HAND_LEFT_POS_STUDS = Vector3.new(-0.02, -0.08, -0.85),
	-- NEGATIVE YAW for the left hand, because its model runs the other way: the right hand's
	-- fingertips are at its mesh +X and the left hand's at its -X (measured on each prepped model's
	-- own bounds). TWIST 180 is what turns the palm UP, so the barrels lie in it rather than on the
	-- back of the hand.
	HAND_LEFT_YAW_DEG = -80,
	HAND_LEFT_PITCH_DEG = -4,
	HAND_LEFT_TWIST_DEG = 180,

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
	-- 4.00, AND IT IS THE ONLY NUMBER IN THIS FILE THAT TWO REQUIREMENTS DECIDE BETWEEN THEM
	-- (task 97, round 2). Everything else about the aimed picture follows from it, so it is written
	-- here once and nothing else restates a value -- the superseded derivations are in git.
	--
	-- WHAT IT HAS TO DO. The eye sits at the gun's own Z = EYE_RELIEF_STUDS - 2.19, because
	-- `Mode.aimOffset` puts the live row's `sightOffsetStuds` on the view axis at this distance.
	--  (a) THE PICTURE. `TARGET-aim.jpg` is the wrist filling the bottom centre, the top tang up it,
	--      the two barrels either side of the rib and the bead above them. At 3.27 the eye sat at
	--      Z = +1.08, which is INSIDE the stock: everything behind the breech was behind the camera
	--      and the aimed view was barrels and nothing else. Anything past about 4.3 and the gun is
	--      small again.
	--  (b) THE GLOVE MUST STAY OUT OF THE LENS, and that is what fixes the lower bound. The right
	--      hand is a 0.95-stud MeshPart on the grip and a Roblox MeshPart renders BOTH faces, so a
	--      model the camera is inside shows its own back surface, unlit -- the pale, smooth blob
	--      round 1 shipped. Its rearmost corner sits at the gun's Z = +1.23 (`HAND_RIGHT_POS_STUDS`
	--      through `Mode.handOffset`, over the row's `sizeStuds`), the recoil spring pulls the whole
	--      gun `RECOIL_MAX_GUN_BACK_STUDS` = 0.25 back toward the eye, and `NEAR_PLANE_MARGIN_STUDS`
	--      = 0.25 is the clearance this file already asks of everything else. 1.23 + 0.25 + 0.25
	--      + 2.19 = 3.92 is the floor; 4.00 leaves 0.33 studs of clearance under the ceiling of the
	--      recoil rather than 0.08.
	--
	-- ASSERTED, NOT REMEMBERED: `tests/server/camera_mode.spec.luau`, "keeps both gloves clear of the
	-- near plane", drives the real composition at the recoil's ceiling and measures every corner of
	-- both hands. Round 1 shipped 3.65 with a comment that said 4.40, and one shot put the cuff
	-- through the lens; nothing caught it, because no spec read a hand against the near plane.
	EYE_RELIEF_STUDS = 4.00,
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
	-- 1.2 SINCE TASK 97, AND IT IS THE OTHER HALF OF THE SAME PICTURE. The cheek angle swings
	-- everything BEHIND the bead downward, and 2.74 studs behind it -- the breech -- 5.4 degrees is a
	-- quarter of a stud of drop, which is what pushed the action and the stock off the bottom of the
	-- frame. In the video you look very nearly ALONG the rib: the barrels' tops sit just under the
	-- bead at the middle of the screen and the wood climbs into the lower third. 1.2 degrees is an
	-- eye a finger's width above the bore at this relief, which is what a low comb actually gives.
	ADS_CHEEK_DEG = 1.2,
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
	-- that is not metal -- so this is brass, `Enum.Material.Metal`, and smaller: 0.05 studs at the
	-- eye relief above is about three quarters of a degree, a dozen pixels in a 784-px viewport at
	-- the aiming field of view. Written as a ratio rather than as a second copy of the relief, which
	-- is the mistake round 1 of task 97 made in three files at once. Brass reads warm against both sky and ground, which is why every classic side-by-side uses
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
	-- 1.0, AND THE FIRST PICK OF 1.4 WAS MEASURED ON SCREEN: at 1.4 the action's own metal (the mesh
	-- carries it at metalness 0.70 / roughness 0.35) blew out to near-white in the aimed view, which
	-- trades one unreadable gun for another. At 1.0 the barrels and the rib keep their highlight and
	-- the walnut still reads as walnut.
	-- 0.8 AND MOVED FORWARD SINCE TASK 97, and the screenshot is why: the aimed view now contains the
	-- action and the stock, and the light sat 0.9 studs BEHIND the gun's centre -- i.e. inside them,
	-- inches from the lens -- so the stock's left flank rendered as a blown-out white patch. It is
	-- the same mistake as a lamp inside the lampshade, and the fix is to put it in front of what it
	-- is meant to light.
	VIEWMODEL_FILL_BRIGHTNESS = 0.8,
	VIEWMODEL_FILL_RANGE_STUDS = 6,
	VIEWMODEL_FILL_COLOR = Color3.fromRGB(255, 244, 224),
	-- Where the light sits relative to the gun's own pivot: up and to the left of the breech, so the
	-- barrels and the rib catch a highlight along their length and the wood behind them is lifted out
	-- of black. Camera space would move with the pose; the gun's own frame does not.
	VIEWMODEL_FILL_OFFSET_STUDS = Vector3.new(-0.45, 0.60, -0.80),

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
