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

-- THE RED DOT'S OWN PLANE, measured on the sight's optical path: its rear glass centres at
-- (x -0.0032, y +0.2318, z +0.5894) and its front glass at (x -0.0033, y +0.2400, z +0.3776), so
-- the dot sits at the MIDDLE of the tube, which is where a reflex sight's dot appears to a shooter
-- looking through it. 0.1159 studs above the bore line.
--
-- IT IS DRAWN AT x = 0 rather than at the glass's measured -0.0032, because the shot leaves at
-- x = 0 (`SemiAuto.CONFIG.MUZZLE_OFFSET`) and a sight that disagrees with the bore is a sight that
-- lies. That 0.8 mm is the MESH sitting off-centre in the Handle, not an aiming error -- the rule
-- `Gun.beadOffset` and `Rifle.Geometry.beadOffset` already state.
local DOT_Y = 0.2359
local DOT_Z = 0.4835
-- 3 mm. A real red dot's is 2-4 MOA, which at any range a hunter shoots is a dot and not a disc;
-- what this number has to be is "small enough to aim with and big enough to find".
local DOT_DIAMETER = 0.012

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
		dotY = DOT_Y * k,
		dotZ = DOT_Z * k,
		dotDiameter = DOT_DIAMETER * k,
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
	return Vector3.new(0, at.dotY, at.dotZ)
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
-- SIX MESHES AND ONE DRAWN PIECE. The six are the model's own groups; the one drawn is the DOT, and
-- it is drawn for a reason that is a fact about Roblox rather than a preference: `SurfaceAppearance`
-- has four channels -- ColorMap, NormalMap, MetalnessMap, RoughnessMap -- and NO emission, so the
-- artist's `M_Sight01_Emissive.png` renders as nothing at all. A red dot that is not emissive is not
-- a red dot.
--
-- `onlyFor = "reddot"` IS TASK 143'S FILTER, kept on purpose when task 148 retired the row that
-- first used it (`backups/2026-10-10-rifle-open-sights.md`). A future row on this same geometry with
-- iron sights would drop the dot and change nothing else.
function Geometry.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local meshAt = CFrame.new(at.meshCentreX, at.meshCentreY, 0)
		* CFrame.Angles(0, math.rad(Geometry.MESH_ROTATION_DEG), 0)
	local look = (config and config.LOOK) or SemiAuto.CONFIG.LOOK
	local sight = Geometry.sightKind(config)
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
			-- IT GETS OUT OF THE SIGHT LINE AS THE EYE ARRIVES (task 227). See `Gun.Piece`'s
			-- `clearFromBlend` for the measurement and the reason: this upload's glass is an opaque
			-- amber face, so with the housing drawn there is no sight picture at all -- the screen
			-- centre is black and the dot inside it is never seen. 0.6 is where `Mode.ease` has the
			-- raise most of the way up, so the housing is solid for the carry, through the swing and
			-- in third person, and only the last of the raise takes it out of the way.
			clearFromBlend = 0.6,
		},
		{
			-- THE DOT. Lit all the time, which is what a red dot is -- and `Neon` is a MATERIAL that
			-- renders bright, not a light source (Roblox emits light only from `PointLight` /
			-- `SpotLight` / `SurfaceLight` instances), so an always-on dot costs the scene nothing.
			-- If Karen looks and wants it off the hip it is a transparency write at one owner.
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
-- and answer `#pieces + 2`; this gun has two, so it answers `+3` -- 7 + 3 = 10 at the shipped
-- sight, and 12 with the two gloves.
--
-- THE DESIGN'S SECTION 14 SAYS 9 AND THAT IS AN ARITHMETIC SLIP IN THE DESIGN, not a different
-- convention: the same row writes the drawn total as "Handle + 2 envelopes + 7 pieces + 2 gloves =
-- 12", and 12 minus the 2 gloves is 10. `semiauto.spec` asserts this against the pieces the
-- geometry actually builds rather than against either number, so it cannot be satisfied by agreeing
-- with a document.
function Geometry.partCount(config): number
	return #Geometry.pieces(config) + 3
end

return Geometry
