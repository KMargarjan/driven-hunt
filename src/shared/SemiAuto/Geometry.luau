--!strict
-- SemiAuto.Geometry: the DRAWN semi-automatic shotgun, as data. The sibling of
-- `src/shared/Gun/init.luau`, `src/shared/Rifle/Geometry.luau` and `src/shared/Lever/Geometry.luau`,
-- with the SAME function set, so `Camera.Viewmodel.buildNewGun` can draw any of the four weapons
-- without learning which one it has (`Weapons.geometry(id)` is the map).
--
-- EVERY BOX AND EVERY POINT HERE WAS MEASURED OFF THE MODEL, in the Handle's own frame, by
-- `driven-hunt-runs/t225/measure.py`, `measure2.py` and `measure3.py` -- which IMPORT
-- `tools/gltf_split.py` and use its measured frame, so there is one frame and not a second copy of
-- the maths. The frame: -Z is the muzzle, +X is right, +Y is up, and the bore line sits at y = +0.12
-- by construction (`boreUpStuds`, the same number all three other guns use).
--
-- THE WHOLE MODEL IS SHIFTED +0.0235 STUDS TO THE RIGHT, ONCE, AND THAT IS A CORRECTION RATHER THAN
-- A TASTE. `gltf_split` centres the model's BOUNDING BOX on the Handle's centre line, and on this
-- gun the charging handle sticks 0.0375 units out of one flank -- so the box's centre is NOT the
-- bore. Measured before the shift, the barrel's own muzzle ring centres at x -0.0235 while the
-- bullet leaves at x = 0 (`SemiAuto.CONFIG.MUZZLE_OFFSET`), which is a drawn gun whose barrel does
-- not point where it shoots. `BORE_X` is that shift and it is applied to every number in this file
-- exactly once; the two checks that it is right are that AFTER it the fore-end's own centre
-- measures x +0.0020 and the sight's glass x -0.0032 -- both inside a millimetre of the centre line,
-- from two independent parts.
--
-- Every box below is already corrected:
--
--   action  X[-0.0739 +0.0893]  Y[-0.1791 +0.2130]  Z[+0.3187 +1.1753]  (receiver, rail, guard,
--                                                                        trigger, bolt release)
--   barrel  X[-0.0847 +0.0894]  Y[-0.1641 +0.1954]  Z[-2.4500 +0.3232]  (barrel, fore-end, cap)
--   stock   X[-0.0768 +0.0797]  Y[-0.4437 +0.1343]  Z[+1.1334 +2.4500]
--   bolt    X[-0.0621 +0.1317]  Y[+0.0609 +0.1718]  Z[+0.3516 +0.7403]  (the charging handle is
--                                                                        the +0.13)
--   lifter  X[-0.0394 +0.0448]  Y[-0.0632 -0.0197]  Z[+0.3897 +0.7298]
--   sight   X[-0.0627 +0.0869]  Y[+0.1850 +0.3379]  Z[+0.3725 +0.5952]
--
-- Those boxes are the FALLBACK -- what is drawn when an upload has not loaded yet -- and all six
-- published meshes carry the WHOLE gun's bounding box (the anchor triangles `gltf_split` adds), so
-- one offset places every one of them and there is no per-piece number to get wrong. Same trick,
-- same reason, as the other three guns'.
--
-- Design: docs/design/semiauto-shotgun.md (sections 5.3, 7)
-- Note:   docs/research/2026-10-20-semiauto-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local SemiAuto = require(script.Parent)

local Geometry = {}

export type Piece = Gun.Piece

-- THE LONG AXIS OF THE MESH IS ITS OWN X, exactly as all three other guns': the split report's
-- `wholeBoxFileAxes.size`. `ServerStorage.Assets` reads this, so the geometry decides the scale
-- rather than a number copied into the manifest.
local WHOLE = Vector3.new(4.9, 0.7817, 0.2165)
Geometry.MESH_SIZE_STUDS = WHOLE
-- WHERE THAT BOX'S CENTRE SITS ON THIS GUN, in the Handle's frame. The model spans y -0.4437 to
-- +0.3379, so its centre is 0.0529 BELOW the Handle's origin; in x it is centred on the BOX, which
-- is why the header's `BORE_X` correction exists and is added here too.
local MESH_CENTRE_Y = -0.052895
-- THE ONE CORRECTION, MEASURED (see the header). Positive is to the gun's right.
local BORE_X = 0.023507

-- THE SAME TWO TURNS EVERY GROUP IN THIS PIPELINE NEEDS: `gltf_split` writes every group with the
-- muzzle at the FILE's +X, and Blender's export plus Roblox's import reverse the model along its own
-- long axis (task 107, measured). Reusing `Gun.MESH_ROTATION_DEG` rather than re-typing 270 means a
-- correction to that measurement reaches all four guns.
Geometry.MESH_ROTATION_DEG = Gun.MESH_ROTATION_DEG

Geometry.FOLDER_NAME = "ViewmodelSemiAuto" -- where the server parks this weapon's published meshes
Geometry.BODY_NAME = "SemiAutoBody"
-- THE GROUP THAT MOVES ON A SHOT. The side-by-side's is `Barrels` and it hinges; the Rigby's is
-- `Bolt` and it slides with a lift; the lever's is `Lever` and it swings; this one is also called
-- `Bolt` and it does neither -- it RECIPROCATES, straight back and straight home, and nothing about
-- it rotates.
--
-- `"straight"` IS A FOURTH `CYCLE_KIND` AND NOT A REUSE OF `"slide"`, and the reason is not
-- tidiness. The Rigby's `"slide"` path spends its first `BOLT_LIFT_FRACTION` turning a bolt handle
-- up and only then draws back; a gas bolt has no handle to turn, so reusing that path would mean a
-- bolt that holds still for the first third of its stroke AND a `boltLift` on this geometry whose
-- only job is to return identity -- a pose dial (`liftDeg`) that moves nothing on screen, which is
-- exactly the silent-number defect task 188 was raised for.
Geometry.CYCLE_GROUP_NAME = "Bolt"
Geometry.CYCLE_KIND = "straight"

-- THE SECOND GROUP THAT MOVES, AND THIS GUN IS THE FIRST TO HAVE ONE (task 225, design 7.2). The
-- bolt moves on `CYCLE`; the shell lifter moves on each `Load` step of `RELOAD`. They are two
-- independent things on two different sequences, so the second is DECLARED BESIDE the first rather
-- than overloaded onto `CYCLE_GROUP_NAME`.
--
-- IT IS ADDITIVE: a geometry without this field has no second group, and the three shipped guns
-- read exactly as they did.
Geometry.LIFT_GROUP_NAME = "Lifter"

-- DOES THIS GUN PUT LOOSE SHELLS IN THE PLAYER'S HANDS? (task 224's declared fact, design 7.5.) The
-- side-by-side does: it is broken over the arm and fed two shells by hand, and `Viewmodel.loadingAt`
-- and `Viewmodel.shells` draw exactly that. This gun does not -- its shells go through a port under
-- a closed receiver, which is a drawn feed nobody has built -- and neither does the lever or the
-- Rigby.
--
-- IT IS A DECLARED FACT AND NOT A BORROWED PREDICATE, for the reason task 224 wrote down: the old
-- gate was `config.MAGAZINE_SWAP ~= nil`, which answers *"does this gun swap a box"*, and
-- underneath it `chamberOffset` is the SIDE-BY-SIDE's chamber mouths at the side-by-side's
-- 4.4-stud layout.
Geometry.HAND_FED_SHELLS = false

-- The six keys the WORLD gun wears (`Weapons.ROWS.semiauto.ASSET_KEYS`): like the lever and unlike
-- model B, this gun is ONE model and both the world Tool and the viewmodel draw it.
Geometry.ASSET_KEYS = table.freeze({
	"semiauto.action",
	"semiauto.barrel",
	"semiauto.stock",
	"semiauto.bolt",
	"semiauto.lifter",
	"semiauto.sight",
})

Geometry.MESH_KEYS = table.freeze({
	Action = "semiauto.action",
	Barrel = "semiauto.barrel",
	Stock = "semiauto.stock",
	Bolt = "semiauto.bolt",
	Lifter = "semiauto.lifter",
	-- `Optic` AND NOT `Sight`, AND THE NAME IS LOAD-BEARING. `"Sight"` is already taken twice
	-- over: `Camera.Viewmodel`'s `SIGHT_NAME` is the ATTACHMENT `buildNewGun` puts on the
	-- Handle to mark where the eye is laid, and `Weapon.Hardware.SIGHT_NAME` is the same name
	-- on the world Tool. `Viewmodel.sight()` resolves it with `FindFirstChild(SIGHT_NAME)` and
	-- then `IsA("Attachment")` -- so a PART of that name is found first, fails the class test,
	-- and the function answers nil. The aimed pose then falls back to
	-- `VIEWMODEL_AIM_OFFSET` and the dot is never put on the camera axis: `eyeReliefStuds` and
	-- `cheekDeg` become dead numbers. MEASURED by the Reviewer, round 1, finding 1.
	--
	-- The piece name, this key and the row's `MESH_NAMES` entry must all say the same word:
	-- `meshFor(piece.name)` looks the published mesh up BY PIECE NAME and `publishGunPiece`
	-- walks this table's keys.
	--
	-- `Optic` IS THE SIGHT'S BODY AND `Dot` IS THE LIT BALL INSIDE IT, and keeping those two
	-- words apart matters: the first cut of this fix called the MESH `RedDot`, and the spec
	-- that looks for the dot then found the sight's housing instead and measured them 0.56
	-- studs apart. One is an uploaded mesh, the other is drawn.
	Optic = "semiauto.sight",
})

-- ---------------------------------------------------------------- THE RED-DOT SIGHT (task 234)
--
-- KAREN, 2026-10-21, with a screenshot of the aimed gun: *"this aiming is not coirrect for semiauto
-- / you know this type of aiming you look from that galss and there is a dot inside right ?"* and
-- *"when we aim we need to see tru that and see that view not the dot"*. What she had was task
-- 227's stopgap: the bought one-piece optic FADED OUT of the sight line (its glass is an opaque
-- amber face that cannot be split out of the mesh in this repo), leaving a bare red ball over the
-- receiver and nothing to look through. 227b queued the real fix; this is it.
--
-- SO THE SIGHT IS DRAWN, AND THE BOUGHT MESH IS NOT WORN BY THE VIEWMODEL (`Optic`'s
-- `skipFor = "reddot"` below). It still dresses the WORLD gun through `ASSET_KEYS` -- what another
-- player sees at thirty studs is the artist's sight, unchanged -- but the man looking THROUGH it
-- gets a hood, a lens and a dot, because an opaque amber face between his eye and the wood is not
-- a sight picture at any transparency.
--
-- Note:   docs/research/2026-10-21-red-dot-sight.md (sections 4 and 5: every number below, and the
--         two parallax-free reticle implementations that were read and REFUSED -- the eye is LAID
--         on this axis by `Mode.aimOffset`, measured, so there is no parallax to cancel)
-- Design: docs/design/semiauto-shotgun.md (section 5.3)

-- THE SIGHT LINE: where the eye is laid, where the dot is drawn, and where the hood is centred.
-- ONE pair of numbers for all three, which is `Gun.beadOffset`'s own rule -- the point the eye is
-- laid on and the thing the eye SEES must come from one expression.
--
-- `SIGHT_Y` IS 0.085 ABOVE THE RECEIVER'S TOP FACE (the action's measured +0.2130), AND THAT
-- CLEARANCE IS THE WHOLE REASON THE SIGHT HAS A MOUNT. With the eye brought to the glass it sits
-- INSIDE the receiver's z span, and Roblox clips at `NearPlaneZ = 0.1`: at the bottom edge of the
-- frame (25 degrees below the axis at FOV 50) the receiver's top is 0.085/tan(25 deg) = 0.182 studs
-- away, outside the clip, so there is no hole in the gun. Laid straight on the rail there would be.
-- MEASURED, not assumed: research note section 6.
--
-- It was +0.2359 until this task -- the bought mesh's own measured glass centre -- and that number
-- is kept in the note and in `backups/2026-10-21_task-234_semiauto-optic-fade.md` (rule 7).
--
-- x IS 0 rather than the glass's measured -0.0032, because the shot leaves at x = 0
-- (`SemiAuto.CONFIG.MUZZLE_OFFSET`) and a sight that disagrees with the bore is a sight that lies.
local SIGHT_Y = 0.298
local DOT_Z = 0.4835

-- THE DOT, HALVED AGAIN AT KAREN'S WORD (task 242). 2026-10-22, verbatim: *"circle is to big and
-- dot is to big"*, with a frame of the aimed gun. 0.003 studs is 0.84 mm at this repo's own
-- 0.28 m/stud, which at the shipped 0.35-stud relief subtends 0.49 degrees against the 0.98 it
-- subtended before -- exactly her "about half", because the dot is small enough that the angle
-- follows the diameter. MEASURED on screen either side of the change by `driven-hunt-runs/234-ring.py`,
-- which finds the reddest blob near the axis: 16 px (1.02 deg) then 9 px (0.57 deg), both centred on
-- the frame's own centre to half a pixel. Same place, same camera, geometry stashed between them.
--
-- IT IS STILL BIGGER THAN A REAL SIGHT AND STILL READS AT 720p: 0.49 degrees is ~7.7 px of a 785-px
-- frame at FOV 50, where a real 2 MOA would be 0.033 degrees and half a pixel. The Director's rule
-- *"sized so it reads at 1280x720 without hiding a deer at 50 m"* is only easier to keep: a stag is
-- 2.1 m tall and subtends 2.4 degrees at 50 m, so the dot now covers a FIFTH of him where task 234's
-- covered two fifths. 0.006 was task 234's number and 3 mm the one before it (2 degrees, most of
-- that stag); both are kept here because the series is the argument.
--
-- `semiauto.spec` asserts the ANGLE, at the shipped relief, bounded at both ends -- so neither this
-- number nor the relief can quietly destroy the sight picture.
local DOT_DIAMETER = 0.003

-- THE HOOD: an OPEN reflex sight's supporting loop, and `open` rather than a tube is arithmetic
-- rather than taste (research note 4(a)). Looking into a TUBE from behind, the clear view is the
-- FRONT aperture: a real Micro T-2 (18 mm aperture, 68.6 mm body) at a cheek weld gives a window of
-- 7.4 degrees, against the 36-46 % of frame width Karen's two reference photographs show. An open
-- hood has no tunnel, so its clear view IS its aperture.
--
-- THE TWO RADII WERE TUNED AGAINST KAREN'S OWN REFERENCE, MEASURED IN PIXELS ON BOTH SIDES
-- (`<runs-dir>/234-ring.py`, which reads a capture and prints the window and the rim as a
-- percentage of the frame width and in degrees):
--
--                        clear window        outer rim
--   reddot-ref-1.png       31 %                38 %
--   reddot-ref-2.png       37 %                46 %
--   first try (0.0554 / wall 0.0183)   25.8 %  39.2 %   <- rim right, window too small
--   SHIPPED (0.0617 / wall 0.0120)     32.4 %  39.2 %   <- ref-1, within a point
--
-- So the OUTER radius is what the first try got right and it did not move; the WALL came down from
-- 5.1 mm to 3.4 mm, which is also what a real hood is. At this repo's 0.28 m/stud the sight is a
-- 41 mm hood over a 35 mm window -- a large-window reflex (a Holosun 510C's is 42 x 27 mm), not a
-- 20 mm Micro, and section 4(a) of the note is why: a Micro's aperture cannot fill a third of the
-- frame at any eye relief a man can hold.
--
-- ...AND THEN KAREN LOOKED THROUGH IT AND SAID THE RING WAS TOO BIG (task 242, 2026-10-22, verbatim:
-- *"circle is to big and dot is to big"*). The reference photographs are of a sight on a bench, not
-- of a man trying to find a boar through one, and at 39 % of frame width the hood was eating the
-- picture it is supposed to frame. The Director's number is ABOUT 30 % SMALLER IN SCREEN SIZE, and
-- the outer radius carries it:
--
--                                      clear window      outer rim    (at relief 0.35, FOV 50)
--   task 234, SHIPPED (0.0617 / 0.0120)   20.0 deg        23.8 deg
--   task 242           (0.0430 / 0.0074)  14.0 deg        16.4 deg    <- 31 % off the rim
--
-- THOSE ARE THE ANGLES THE CONSTANTS GIVE, and `semiauto.spec` asserts them both rather than
-- trusting them. THE SCREEN AGREES, on a pair taken at the same spot with the same camera, the
-- geometry stashed and restored between them (`.screenshots/242-2-before-semiauto-paired.png` and
-- `242-2-after-semiauto.png`, 947 x 785). Measured on ONE row 58 px below the sight line -- the row
-- where BOTH frames have grass behind the hood on both sides, which is what makes an edge findable
-- at all -- the hood's outer radius is 192 px and then 131: 32 % smaller, against 31 % predicted.
--
-- A RIM EDGE CANNOT BE READ OFF THE SIGHT LINE'S OWN ROW by `driven-hunt-runs/234-ring.py`, and that
-- is a note for whoever measures this next: the hood is black, the wood behind it is black on one
-- side and sunlit white on the other, so the tool's outward scan merges the hood into the trees. The
-- DOT can be read anywhere, because it is the only red thing on the screen: 16 px then 9 px,
-- 1.02 then 0.57 degrees, both centred on the frame's own centre to half a pixel.
--
-- THE RIM IS THINNED AS WELL AS SHRUNK, and that is what keeps the view-through: taken in proportion
-- the window would have fallen to 13.8 degrees, so the wall comes down from 3.4 mm to 2.1 mm -- which
-- is still a real hood's rim, and buys back a fifth of a degree of glass. The sight is now a 28 mm
-- hood over a 24 mm window at this repo's 0.28 m/stud: a compact reflex rather than a Holosun 510C,
-- which is the trade Karen asked for.
--
-- THE ALIGNMENT IS UNTOUCHED, which is the one thing task 234 bought that must not be spent:
-- `SIGHT_Y`, `DOT_Z` and `eyeReliefStuds` are the same three numbers, so the eye is laid in the same
-- place and the dot sits on the same axis. Nothing moves in z, so the near plane is where it was --
-- the receiver's top is still 0.085 below the sight line and still 0.182 studs away at the bottom
-- edge of the frame, against Roblox's 0.1 clip. Shrinking a ring that is 0.325 studs from the eye
-- only ever moves it FURTHER from the clip.
local HOOD_INNER_RADIUS = 0.043
local HOOD_WALL = 0.0074
local HOOD_DEPTH = 0.05
-- 24 SEGMENTS, because Roblox has no hollow primitive and no built-in torus, and a ring Decal would
-- need an upload nobody has approved.
--
-- 16 WAS TRIED FIRST AND LOOKED LIKE A 16-GON (`.screenshots/234-a3-aim.png`), which is the sort of
-- thing arithmetic said would be invisible and a frame said was not: the sagitta at 16 is
-- R*(1-cos(11.25 deg)) = 0.0012 studs, 0.2 degrees, about 3 px of a 278 px window -- and 3 px of
-- straight edge repeated sixteen times around a circle reads as a nut, not a hood. At 24 it is
-- R*(1-cos(7.5 deg)) = 0.00053 studs, 0.086 degrees, about one pixel. Rule 5: the screen decided.
local HOOD_SEGMENTS = 24
-- THE LENS, 0.012 studs (3 mm) in front of the eye's side of the dot, so the player looks THROUGH
-- it at a dot sitting inside the hood behind it. Lightly tinted, which is Karen's own word
-- (*"verry similar just red light red and then dot acordingly to be visble"*) and her ref-1's
-- blue-green cast; 0.86 is "clear glass with a tint", not a window you cannot see through.
local GLASS_THICKNESS = 0.004
local GLASS_AT_Z = 0.012 -- toward the EYE (+Z is backward in this frame)
-- 0.87 AND A COOL TINT, WHICH IS THE THIRD VALUE TRIED AND THE FIRST ONE THAT IS GLASS. 0.86 over
-- RGB(196,222,216) laid milk over the whole picture; 0.90 over RGB(168,200,194) could not be seen
-- at all, which is a lens the player has no reason to believe is there. Karen asked to see the
-- view THROUGH it, not past it.
local GLASS_TRANSPARENCY = 0.87
local GLASS_TINT = Color3.fromRGB(150, 196, 188)
-- THE MOUNT, from the receiver's top face up to the hood's underside: the 0.085 of section 6, as a
-- part. It sinks 0.010 into the rail so there is no hairline of daylight under a sight that is
-- bolted down.
local MOUNT_WIDTH = 0.048
local MOUNT_LENGTH = 0.09
local RAIL_TOP_Y = 0.213
local MOUNT_SINK = 0.01

-- THE LIFTER'S PIVOT: the centroid of the tray's REAR-most 8 % in z that also lies in its upper
-- half -- the material around the pin and nothing else (26 vertices). The tray turns about this
-- point and about nothing else. Its x is written as 0 and not its measured +0.0056 because a
-- rotation about +X does not depend on the pivot's x at all, so a number there would be read as
-- meaningful and decide nothing.
local LIFTER_PIVOT = Vector3.new(0, -0.0319, 0.7294)
-- THE TRAY'S FREE END: the centroid of its front-most 8 % (62 vertices), 0.3331 studs from the
-- pivot. This is the point `lifterTipOffset` answers for, and it is the one a spec can FAIL on --
-- `semiauto.spec` asserts the end is HIGHER at full throw than at rest, and by at least one hull
-- diameter, because a tray that rises less than that could not lift a shell to the chamber mouth.
local LIFTER_TIP = Vector3.new(0, -0.0575, 0.3973)

-- HOW FAR BACK THE BOLT CAN GO BEFORE IT LEAVES THE RECEIVER: the bolt's rear face is at z +0.7403
-- and the receiver's is at +1.1691, so 0.4288 studs. `poses.json`'s `cycle.drawStuds` must sit under
-- that and over one 76 mm hull (0.2932 studs), or the hull could not clear the port. Published so
-- the spec can bound the pose data rather than trusting it.
Geometry.BOLT_TRAVEL_MAX = 0.4288

-- THE STOCK'S PISTOL GRIP (the RIGHT hand), as a LINE and a radius -- task 188's four tolerances,
-- and the design's item 9. Measured as the stock's material BELOW the bore line and BEHIND the
-- trigger guard, which on a shotgun stock is the grip and nothing else; the axis is the
-- least-squares line through five 0.06-stud slice centres over z +1.40..+1.64.
--
-- A HAND GRIPS A GRIP, NOT A POINT, which is why the axis is published beside the point:
-- `poses.json` is checked against the LINE. Task 188 exists because a pose 0.158 along the axis put
-- the hand on the comb and the spec passed anyway.
local GRIP_WRIST = Vector3.new(0, -0.1275, 1.5234)
local GRIP_WRIST_DIR = Vector3.new(0, -0.0120, 1).Unit -- 0.7 degrees of rake: this grip is straight
local GRIP_RADIUS = 0.0601 -- half the narrowest slice across (0.1202)
local GRIP_HALF_LENGTH = 0.1200 -- half the holdable span, along the axis

-- THE FORE-END (the LEFT hand), the same way. It is a near-constant section 0.17 wide and 0.21 high
-- running under the barrel, so its axis IS the bore's direction and the only question is where
-- along it a hand sits. The span below is the part forward of the receiver that a hand can actually
-- close on, held back from both ends: at the muzzle end the magazine cap, at the breech end the
-- receiver.
--
-- THE LEFT HAND IS NOT A RIDER ON THIS GUN. The fore-end is bolted to the barrel and the barrel
-- does not move -- only the bolt and the tray do -- so `Viewmodel.poseHands`' `CYCLE_KIND ==
-- "hinge"` test answers false here, which is the right answer and is why that function needs no
-- edit for this weapon.
local FORE_GRIP = Vector3.new(0, 0.0080, -0.5250)
local FORE_DIR = Vector3.new(0, 0, 1)
local FORE_RADIUS = 0.0768
local FORE_HALF_LENGTH = 0.3250

local STEEL_MATERIAL = Enum.Material.SmoothPlastic -- `Metal` mirrors the sky; see `Gun`'s own note

local function span(low: number, high: number): (number, number)
	return high - low, (high + low) / 2
end

-- Every measurement this gun has, scaled by the Handle's length so that a different `HANDLE_SIZE.Z`
-- moves the whole gun together. 4.9 is what the meshes were baked at, so at 4.9 the numbers below
-- are exactly the measured ones.
function Geometry.layout(config)
	local total = (config and config.HANDLE_SIZE or SemiAuto.CONFIG.HANDLE_SIZE).Z
	local k = total / 4.9
	local actionW, actionX = span(-0.0739 * k, 0.0893 * k)
	local actionH, actionY = span(-0.1791 * k, 0.2130 * k)
	local actionL, actionZ = span(0.3187 * k, 1.1753 * k)
	local barrelW, barrelX = span(-0.0847 * k, 0.0894 * k)
	local barrelH, barrelY = span(-0.1641 * k, 0.1954 * k)
	local barrelL, barrelZ = span(-2.45 * k, 0.3232 * k)
	local stockW, stockX = span(-0.0768 * k, 0.0797 * k)
	local stockH, stockY = span(-0.4437 * k, 0.1343 * k)
	local stockL, stockZ = span(1.1334 * k, 2.45 * k)
	local boltW, boltX = span(-0.0621 * k, 0.1317 * k)
	local boltH, boltY = span(0.0609 * k, 0.1718 * k)
	local boltL, boltZ = span(0.3516 * k, 0.7403 * k)
	local liftW, liftX = span(-0.0394 * k, 0.0448 * k)
	local liftH, liftY = span(-0.0632 * k, -0.0197 * k)
	local liftL, liftZ = span(0.3897 * k, 0.7298 * k)
	local sightW, sightX = span(-0.0627 * k, 0.0869 * k)
	local sightH, sightY = span(0.185 * k, 0.3379 * k)
	local sightL, sightZ = span(0.3725 * k, 0.5952 * k)
	return table.freeze({
		total = total,
		half = total / 2,
		muzzleZ = -total / 2,
		meshCentreX = BORE_X * k,
		meshCentreY = MESH_CENTRE_Y * k,
		sightLineY = SIGHT_Y * k,
		dotZ = DOT_Z * k,
		dotDiameter = DOT_DIAMETER * k,
		-- THE DRAWN SIGHT'S OWN BOX, scaled with everything else so a different `HANDLE_SIZE.Z`
		-- moves the hood with the gun it is bolted to.
		hoodInnerRadius = HOOD_INNER_RADIUS * k,
		hoodOuterRadius = (HOOD_INNER_RADIUS + HOOD_WALL) * k,
		hoodWall = HOOD_WALL * k,
		hoodDepth = HOOD_DEPTH * k,
		glassThickness = GLASS_THICKNESS * k,
		glassAtZ = GLASS_AT_Z * k,
		railTopY = RAIL_TOP_Y * k,
		mountWidth = MOUNT_WIDTH * k,
		mountLength = MOUNT_LENGTH * k,
		mountSink = MOUNT_SINK * k,
		boltTravelMax = Geometry.BOLT_TRAVEL_MAX * k,
		action = { size = Vector3.new(actionW, actionH, actionL), at = Vector3.new(actionX, actionY, actionZ) },
		barrel = { size = Vector3.new(barrelW, barrelH, barrelL), at = Vector3.new(barrelX, barrelY, barrelZ) },
		stock = { size = Vector3.new(stockW, stockH, stockL), at = Vector3.new(stockX, stockY, stockZ) },
		bolt = { size = Vector3.new(boltW, boltH, boltL), at = Vector3.new(boltX, boltY, boltZ) },
		lifter = { size = Vector3.new(liftW, liftH, liftL), at = Vector3.new(liftX, liftY, liftZ) },
		sight = { size = Vector3.new(sightW, sightH, sightL), at = Vector3.new(sightX, sightY, sightZ) },
		-- THE GENERIC PAIR THE VIEWMODEL READS for the group that moves on a shot (task 224):
		-- `barrelLength`/`barrelZ` is the side-by-side's name and `bolt.size.Z`/`bolt.at.Z` the
		-- Rigby's; these two say the same thing for any gun and are DERIVED from this weapon's own
		-- `bolt` box above, so there is one measurement here and not two that can drift.
		cycleLength = boltL,
		cycleZ = boltZ,
		-- ...AND THE SAME PAIR FOR THE SECOND MOVING GROUP (task 225). `buildNewGun` sizes and
		-- places the lifter's envelope from these, exactly as it does the cycle group's.
		liftLength = liftL,
		liftZ = liftZ,
	})
end

-- WHICH SIGHT THIS ROW CARRIES. `"reddot"` by default, where the Rigby's is `"scope"` and the
-- lever's is `"bead"`. The function is here because the function SET is the contract: a caller that
-- asks all four geometries the same question must get an answer from each.
function Geometry.sightKind(config): string
	return (config and config.SIGHT) or "reddot"
end

-- WHERE THE DOT IS, AND THE ONE PLACE THAT DECIDES IT -- the rule the other three guns already keep
-- (`Gun.beadOffset`, `Rifle.Geometry.beadOffset`, `Lever.Geometry.beadOffset`): the point the eye is
-- laid on and the thing the eye SEES must come from one expression, because nothing in the game
-- compares two copies. `Geometry.pieces` draws the dot here and `Geometry.sight` aims through here.
function Geometry.beadOffset(config): Vector3
	local at = Geometry.layout(config)
	return Vector3.new(0, at.sightLineY, at.dotZ)
end

-- WHERE THE EYE IS LAID. Identity rotation: (0, 0, -1) is already the muzzle direction in this frame
-- and the dot is on the gun's centre line, so the sight looks exactly where the barrel points.
function Geometry.sight(config): CFrame
	return CFrame.new(Geometry.beadOffset(config))
end

function Geometry.muzzle(config): CFrame
	local at = Geometry.layout(config)
	return CFrame.new(0, 0.12 * (at.total / 4.9), at.muzzleZ)
end

-- THE PIN THE SIDE-BY-SIDE SWINGS ON. This gun has none, and a caller written for that gun must
-- still get a point on the gun rather than nil -- `Camera.Viewmodel.hinge` reads this BEFORE it
-- branches. The bolt's own rest centre is the honest answer: it is the thing that moves.
--
-- IT IS INERT ON THIS GUN, and so is `poses.json`'s `cycle.hingeStuds` beside it: the `"straight"`
-- path reads `drawStuds` and turns about nothing. Both ship because the flat-name set every weapon
-- publishes is the side-by-side's, which is the lever's `hingeStuds`' own reason.
function Geometry.hinge(config): Vector3
	local at = Geometry.layout(config)
	return Vector3.new(0, at.bolt.at.Y, at.bolt.at.Z)
end

-- HOW FAR BACK THE BOLT IS. `progress` is 0 at rest and 1 at full travel; the CFrame is in the gun's
-- own frame and `Camera.Viewmodel.hinge`'s `"straight"` path is its only caller.
--
-- THE SIGN LIVES HERE, AND THAT IS THE WHOLE REASON THIS IS A FUNCTION AND NOT A `CFrame.new` AT
-- THE CALL SITE -- task 188's lesson, restated by task 224's lever. In the Handle's frame -Z is the
-- muzzle, so BACK IS +Z, and this is the one place in the repo that says so about this gun. Writing
-- it inline would put the sign next to the arithmetic and out of reach of a spec.
--
-- `progress` IS CLAMPED RATHER THAN TRUSTED, and `studs` is bounded by what was measured: the bolt
-- has 0.4288 studs of receiver behind it, and a caller that passed more would draw it out of the
-- back of the gun. `semiauto.spec` drives both ends.
function Geometry.boltTravel(config, studs: number, progress: number): CFrame
	local at = Geometry.layout(config)
	local back = math.clamp(studs or 0, 0, at.boltTravelMax) * math.clamp(progress, 0, 1)
	return CFrame.new(0, 0, back)
end

-- THE LIFTER'S PIVOT, in the gun's frame.
function Geometry.lifterHinge(config): Vector3
	local at = Geometry.layout(config)
	return LIFTER_PIVOT * (at.total / 4.9)
end

-- HOW FAR, AND WHICH WAY, THE TRAY SWINGS. `progress` is 0 at rest and 1 at full lift.
--
-- POSITIVE ABOUT +X RAISES THE FREE END, and it was measured on the model rather than argued about.
-- The tray pins at the REAR of the port (z +0.7294) and its free end hangs forward and low
-- (z +0.3973, y -0.0575), so rotating it positively about +X carries that end UP:
--
--   10 deg -> +0.058 studs      20 deg -> +0.115 studs
--   15 deg -> +0.087 studs      30 deg -> +0.170 studs
--
-- One 12-gauge hull is 20.5 mm across = 0.079 studs, so anything from about 14 degrees up actually
-- lifts a shell. The shipped `cycle.lifterDeg` is 20.
--
-- IT TAKES THE ANGLE RATHER THAN READING IT, because the two live in different tables: the pivot is
-- the WEAPON ROW's (it scales with `HANDLE_SIZE`) and the throw is the POSE DATA's
-- (`cycle.lifterDeg`, which the Director tunes live).
function Geometry.lifterSwing(config, throwDeg: number, progress: number): CFrame
	local pivot = CFrame.new(Geometry.lifterHinge(config))
	local degrees = (throwDeg or 0) * math.clamp(progress, 0, 1)
	return pivot * CFrame.Angles(math.rad(degrees), 0, 0) * pivot:Inverse()
end

-- WHERE THE TRAY'S FREE END ENDS UP, for a given throw and progress. This exists so the sign and the
-- reach are FALSIFIABLE: `semiauto.spec` asserts this point is higher at progress 1 than at 0, and
-- higher by at least one hull diameter. A sign nobody can see is a sign that ships wrong.
function Geometry.lifterTipOffset(config, throwDeg: number, progress: number): Vector3
	local at = Geometry.layout(config)
	local tip = LIFTER_TIP * (at.total / 4.9)
	return Geometry.lifterSwing(config, throwDeg, progress) * tip
end

-- THE STOCK'S GRIP: a POINT on it and the DIRECTION it runs. The hip and the aimed poses put the
-- right hand's own grip point on this LINE -- a hand slides a little along a grip and is still
-- holding it, but a hand off the line is a hand beside the gun. SAME NAMES as the Rigby's and the
-- lever's, so one spec helper checks every gun's hold.
function Geometry.gripOffset(config): Vector3
	local at = Geometry.layout(config)
	return GRIP_WRIST * (at.total / 4.9)
end

function Geometry.gripAxis(config): Vector3
	local _ = config -- a direction does not scale
	return GRIP_WRIST_DIR
end

function Geometry.gripRadius(config): number
	local at = Geometry.layout(config)
	return GRIP_RADIUS * (at.total / 4.9)
end

function Geometry.gripHalfLength(config): number
	local at = Geometry.layout(config)
	return GRIP_HALF_LENGTH * (at.total / 4.9)
end

-- How far ALONG the grip a point sits, signed, from `gripOffset`. Positive is toward the butt.
function Geometry.alongGripAxis(config, point: Vector3): number
	return (point - Geometry.gripOffset(config)):Dot(Geometry.gripAxis(config))
end

-- How far a point is from the grip's line. The one expression that answers "is the hand on the
-- grip", so the spec and any future tool cannot disagree about it.
function Geometry.offGripAxis(config, point: Vector3): number
	local along = point - Geometry.gripOffset(config)
	local dir = Geometry.gripAxis(config)
	return (along - dir * along:Dot(dir)).Magnitude
end

-- THE FORE-END, the same four answers for the LEFT hand. This gun publishes them where the other
-- three do not, because this is the first gun whose left hand has a long smooth thing to sit
-- anywhere on: the design's item 9 asks for both holds bounded, and a bound on one hand only would
-- let the other slide off the gun unnoticed.
function Geometry.foreOffset(config): Vector3
	local at = Geometry.layout(config)
	return FORE_GRIP * (at.total / 4.9)
end

function Geometry.foreAxis(config): Vector3
	local _ = config
	return FORE_DIR
end

function Geometry.foreRadius(config): number
	local at = Geometry.layout(config)
	return FORE_RADIUS * (at.total / 4.9)
end

function Geometry.foreHalfLength(config): number
	local at = Geometry.layout(config)
	return FORE_HALF_LENGTH * (at.total / 4.9)
end

function Geometry.alongForeAxis(config, point: Vector3): number
	return (point - Geometry.foreOffset(config)):Dot(Geometry.foreAxis(config))
end

function Geometry.offForeAxis(config, point: Vector3): number
	local along = point - Geometry.foreOffset(config)
	local dir = Geometry.foreAxis(config)
	return (along - dir * along:Dot(dir)).Magnitude
end

-- Every piece of the first-person semi-automatic shotgun, in build order. Pure.
--
-- FIVE MESHES AND A DRAWN RED-DOT SIGHT (task 234). The five are the model's own groups minus its
-- optic; the drawn sight is a MOUNT, a hood of `HOOD_SEGMENTS` segments, a LENS and the DOT.
--
-- WHY THE OPTIC IS DRAWN AND NOT WORN. Two facts about Roblox, neither of them a preference.
-- First, `SurfaceAppearance` has four channels -- ColorMap, NormalMap, MetalnessMap, RoughnessMap --
-- and NO emission, so the artist's `M_Sight01_Emissive.png` renders as nothing at all: a red dot
-- that is not emissive is not a red dot, and that is why the DOT was already drawn before this task.
-- Second, the upload is ONE MeshPart whose glass is a solid amber face and a mesh cannot be split in
-- this repo, so there is no way to make that face transparent without making the whole housing
-- transparent -- which is exactly what task 227 did, and what left Karen a bare ball floating over
-- the receiver. The housing is therefore drawn too, and the bought mesh dresses the WORLD gun alone.
--
-- `onlyFor` / `skipFor` ARE TASK 143'S FILTER, and the whole sight now rides them: every drawn piece
-- is `onlyFor = "reddot"` and the bought `Optic` is `skipFor = "reddot"`, so a future row on this
-- same geometry with iron sights gets the artist's housing back and loses the hood, the lens and the
-- dot, in one list, with nothing else changed.
function Geometry.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local meshAt = CFrame.new(at.meshCentreX, at.meshCentreY, 0)
		* CFrame.Angles(0, math.rad(Geometry.MESH_ROTATION_DEG), 0)
	local look = (config and config.LOOK) or SemiAuto.CONFIG.LOOK
	local sight = Geometry.sightKind(config)
	-- `or look.sight` IS A FALLBACK AND NOT A SECOND OPINION: a caller may pass a `LOOK` table
	-- written before task 234 added the hood's own key (`ShapeSemiAuto` builds one inline), and a nil
	-- `Color3` is an error at the drawer rather than a wrong colour. The shipped row carries both.
	local hoodColor = look.hood or look.sight
	local all: { Piece } = {
		{
			name = "Stock",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Stock,
			meshOffset = meshAt,
			size = at.stock.size,
			offset = CFrame.new(at.stock.at),
			color = look.wood,
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			-- The barrel, the fore-end over the gas system and the magazine cap: one upload,
			-- because they are one material and none of them moves.
			name = "Barrel",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Barrel,
			meshOffset = meshAt,
			size = at.barrel.size,
			offset = CFrame.new(at.barrel.at),
			color = look.barrel,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		{
			-- THE BODY: receiver, Picatinny rail, trigger guard, trigger and the bolt-release
			-- button. Worn as `Model`, which is the piece that must be there for the gun to count as
			-- dressed (`Hardware.wearsMesh`).
			name = "Action",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Action,
			meshOffset = meshAt,
			size = at.action.size,
			offset = CFrame.new(at.action.at),
			color = look.action,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		{
			-- NOT `"Sight"`: that name is the aim ATTACHMENT's, on this gun and on the world Tool
			-- alike. See `MESH_KEYS` above for what happens when a part takes it.
			name = "Optic",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Optic,
			meshOffset = meshAt,
			size = at.sight.size,
			offset = CFrame.new(at.sight.at),
			color = look.sight,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
			-- THE VIEWMODEL DOES NOT WEAR IT ON THE RED-DOT ROW (task 234), and that is the whole
			-- shape of this fix. This upload's glass is an opaque amber face and cannot be split out
			-- of the mesh in this repo, so between the eye and the wood it is a wall at any
			-- transparency; task 227 FADED it (`clearFromBlend` below) and left the player a bare
			-- ball floating over the receiver, which is the defect Karen reported
			-- (`.screenshots/234-before-semiauto-aim.png`). The drawn hood, lens and dot below take
			-- its place. `ASSET_KEYS` still carries `semiauto.sight`, so the WORLD gun -- what
			-- another player sees at thirty studs -- wears the artist's sight exactly as before.
			skipFor = "reddot",
			-- ...AND THE FADE STAYS ON IT FOR ANY ROW THAT IS NOT THE RED DOT. See `Gun.Piece`'s
			-- `clearFromBlend`: 0.6 is where `Mode.ease` has the raise most of the way up, so the
			-- housing is solid for the carry, through the swing and in third person, and only the
			-- last of the raise takes it out of the way. No shipped row takes this branch today --
			-- the same standing `onlyFor` has had since task 148 -- and it is kept for the reason
			-- the research note's section 7 gives.
			clearFromBlend = 0.6,
		},
		{
			-- THE MOUNT: from the receiver's top face up to the hood's underside, which is the
			-- 0.085 studs of clearance the near plane needs (see `SIGHT_Y`). It sinks `MOUNT_SINK`
			-- into the rail so a bolted-down sight has no hairline of daylight under it.
			name = "SightMount",
			group = "body" :: Gun.Group,
			onlyFor = "reddot",
			size = Vector3.new(
				at.mountWidth,
				(at.sightLineY - at.hoodOuterRadius) - (at.railTopY - at.mountSink),
				at.mountLength
			),
			offset = CFrame.new(0, ((at.sightLineY - at.hoodOuterRadius) + (at.railTopY - at.mountSink)) / 2, at.dotZ),
			color = hoodColor,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		{
			-- THE LENS. Clear, lightly tinted, and the one piece in this gun that is MEANT to be
			-- looked through -- the same job the Rigby's scope glass has and the same answer
			-- (`transparency`, which `Camera.Viewmodel.buildNewGun` writes onto the drawn part).
			name = "SightGlass",
			group = "body" :: Gun.Group,
			onlyFor = "reddot",
			-- A Cylinder's length runs along its OWN X, so it is laid onto the sight axis -- the
			-- same quarter turn `Weapon.ShapeSemiAuto` gives the barrel.
			size = Vector3.new(at.glassThickness, at.hoodInnerRadius * 2, at.hoodInnerRadius * 2),
			offset = CFrame.new(0, at.sightLineY, at.dotZ + at.glassAtZ) * CFrame.Angles(0, math.pi / 2, 0),
			color = GLASS_TINT,
			-- `SmoothPlastic` AND NOT `Glass`, which is the Rigby's scope glass's own choice and
			-- for the same reason `STEEL_MATERIAL` is not `Metal` on this gun: Roblox's `Glass`
			-- reflects the sky and goes near-opaque at a glancing angle, which is the one thing a
			-- sight the player looks THROUGH must never do.
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Cylinder,
			transparency = GLASS_TRANSPARENCY,
		},
		{
			-- THE DOT. Lit all the time, which is what a red dot is -- and `Neon` is a MATERIAL that
			-- renders bright, not a light source (Roblox emits light only from `PointLight` /
			-- `SpotLight` / `SurfaceLight` instances), so an always-on dot costs the scene nothing.
			-- It sits INSIDE the hood, behind the lens, on the axis the eye is laid on -- which is
			-- `Geometry.beadOffset` and not a second copy of it.
			name = "Dot",
			group = "body" :: Gun.Group,
			onlyFor = "reddot",
			size = Vector3.new(at.dotDiameter, at.dotDiameter, at.dotDiameter),
			offset = CFrame.new(Geometry.beadOffset(config)),
			color = look.dot,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
		},
		{
			-- THE PIECE THAT MOVES ON A SHOT: the bolt and its charging handle. `Gun.Group`'s
			-- second value is the cycle group whatever the gun calls it.
			name = Geometry.CYCLE_GROUP_NAME,
			group = "barrels" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Bolt,
			meshOffset = meshAt,
			size = at.bolt.size,
			offset = CFrame.new(at.bolt.at),
			color = look.bolt,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		{
			-- THE PIECE THAT MOVES ON A RELOAD: the shell lifter in the loading port. The first
			-- second moving group in this repo (`Gun.Group`'s third value).
			name = Geometry.LIFT_GROUP_NAME,
			group = "lift" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Lifter,
			meshOffset = meshAt,
			size = at.lifter.size,
			offset = CFrame.new(at.lifter.at),
			color = look.lifter,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
	}
	-- THE HOOD, AS A RING OF STRAIGHT SEGMENTS. Roblox has no hollow primitive and no torus, so an
	-- annulus is N boxes on a circle; `HOOD_SEGMENTS` carries the measurement that says 16 is round
	-- enough. Each box is `chord` across the tangent, `hoodWall` deep in the radius and `hoodDepth`
	-- along the sight axis.
	--
	-- THE CHORD CIRCUMSCRIBES THE **OUTER** RADIUS -- 2*rOuter*tan(pi/N) -- AND THE FIRST TRY USED
	-- THE MIDDLE ONE, WHICH IS A DIFFERENCE YOU CAN SEE. At the seam between two neighbours the
	-- outermost covered point is at tangential offset `rOuter*sin(pi/N)`, so a chord sized on the
	-- MIDDLE radius leaves 2.7 degrees of daylight at every one of the sixteen joints: the frame
	-- came back a cog wheel (`.screenshots/234-a2-aim.png`). Sized on the outer radius the
	-- neighbours touch exactly there and overlap everywhere inside it, and the only cost is that the
	-- outer corners stand 1.9 % proud of the circle.
	--
	-- BUILT IN THE LOOP AND NOT TYPED OUT, because sixteen hand-written offsets are sixteen chances
	-- to get one wrong and nothing in a frame would show which.
	local hoodMid = (at.hoodInnerRadius + at.hoodOuterRadius) / 2
	local hoodChord = 2 * at.hoodOuterRadius * math.tan(math.pi / HOOD_SEGMENTS)
	for index = 1, HOOD_SEGMENTS do
		local angle = (index - 1) * (2 * math.pi / HOOD_SEGMENTS)
		table.insert(all, {
			name = string.format("SightHood%d", index),
			group = "body" :: Gun.Group,
			onlyFor = "reddot",
			size = Vector3.new(hoodChord, at.hoodWall, at.hoodDepth),
			offset = CFrame.new(0, at.sightLineY, at.dotZ) * CFrame.Angles(0, 0, angle) * CFrame.new(0, hoodMid, 0),
			color = hoodColor,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		})
	end

	-- ONE LIST, FILTERED BY THE ROW'S SIGHT (task 143): `onlyFor` keeps a piece just for that sight
	-- and `skipFor` drops one for it, so one geometry can draw this gun with the dot or without it.
	local kept: { Piece } = {}
	for _, piece in ipairs(all) do
		local skip = (piece.skipFor ~= nil and piece.skipFor == sight)
			or (piece.onlyFor ~= nil and piece.onlyFor ~= sight)
		if not skip then
			table.insert(kept, piece)
		end
	end
	return kept
end

-- WHAT `buildNewGun` ACTUALLY PARENTS UNDER THE CLONE, gloves excluded: every piece, plus the
-- Handle, plus one invisible envelope per moving group. The other three guns have ONE moving group
-- and answer `#pieces + 2`; this gun has two, so it answers `+3`.
--
-- AT THE SHIPPED SIGHT THAT IS NOW 5 meshes + mount + lens + dot + `HOOD_SEGMENTS` = 24 pieces,
-- 27 parts, 29 with the two gloves. It was 7 + 3 = 10 before task 234 drew the sight, and the
-- DESIGN'S SECTION 14 SAYS 9, which was an arithmetic slip in the design even then (its own row
-- writes "Handle + 2 envelopes + 7 pieces + 2 gloves = 12", and 12 minus the 2 gloves is 10).
-- `semiauto.spec` asserts this against the pieces the geometry actually builds rather than against
-- any number in a document, so it cannot be satisfied by agreeing with one.
--
-- SIXTEEN SEGMENTS IS NOT A COST WORTH MINDING: this is built ONCE per gun change, not per frame,
-- and the drawn ring is still fewer parts than one of the meshes it replaces has triangles.
function Geometry.partCount(config): number
	return #Geometry.pieces(config) + 3
end

return Geometry
