--!strict
-- Lever.Geometry: the DRAWN lever-action rifle, as data. The sibling of `src/shared/Gun/init.luau`
-- and `src/shared/Rifle/Geometry.luau`, with the SAME function set, so
-- `Camera.Viewmodel.buildNewGun` can draw any of the three weapons without learning which one it
-- has (`Weapons.geometry(id)` is the map).
--
-- EVERY BOX AND EVERY POINT HERE WAS MEASURED OFF THE MODEL, in the Handle's own frame, by
-- `driven-hunt-runs/t224/measure.py` -- which IMPORTS `tools/gltf_split.py` and uses its measured
-- frame, so there is one frame and not a second copy of the maths. The frame: -Z is the muzzle, +X
-- is right, +Y is up, and the bore line sits at y = +0.12 by construction (`boreUpStuds`, the same
-- number both other guns use). Measured against that construction, the barrel's own muzzle ring
-- centres at y +0.1192 -- 0.0008 studs out, which is the ring against its own principal axis.
--
--   stock   X[-0.1046 +0.1046]  Y[-0.5874 +0.0461]  Z[+0.5491 +2.0000]
--   action  X[-0.0706 +0.0696]  Y[-0.3167 +0.2301]  Z[-2.0000 +0.9645]   (receiver, barrel, rail,
--                                                                         sights, tube, fore-end)
--   lever   X[-0.0192 +0.0191]  Y[-0.3949 +0.0138]  Z[+0.1749 +0.8357]   (the finger lever)
--
-- Those boxes are the FALLBACK -- what is drawn when an upload has not loaded yet -- and all three
-- published meshes carry the WHOLE gun's bounding box (the anchor triangles `gltf_split` adds), so
-- one offset places every one of them and there is no per-piece number to get wrong. Same trick,
-- same reason, as model B's and the Rigby's.
--
-- Design: docs/design/lever-rifle.md (sections 5.3, 7)
-- Note:   docs/research/2026-10-20-lever-action.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Lever = require(script.Parent)

local Geometry = {}

export type Piece = Gun.Piece

-- THE LONG AXIS OF THE MESH IS ITS OWN X, exactly as both other guns': the split report's
-- `wholeBoxFileAxes.size`. `ServerStorage.Assets` reads this, so the geometry decides the scale
-- rather than a number copied into the manifest.
local WHOLE = Vector3.new(4.0, 0.8175, 0.2092)
Geometry.MESH_SIZE_STUDS = WHOLE
-- WHERE THAT BOX'S CENTRE SITS ON THIS GUN, in the Handle's frame: the model spans y -0.5874 to
-- +0.2301, so its centre is 0.1787 BELOW the Handle's origin. x and z are centred by construction
-- (the muzzle is at -2.0 and the butt plate at +2.0).
local MESH_CENTRE_Y = -0.178650

-- THE SAME TWO TURNS EVERY GROUP IN THIS PIPELINE NEEDS: `gltf_split` writes every group with the
-- muzzle at the FILE's +X, and Blender's export plus Roblox's import reverse the model along its own
-- long axis (task 107, measured). Reusing `Gun.MESH_ROTATION_DEG` rather than re-typing 270 means a
-- correction to that measurement reaches all three guns.
Geometry.MESH_ROTATION_DEG = Gun.MESH_ROTATION_DEG

Geometry.FOLDER_NAME = "ViewmodelLever" -- where the server parks this weapon's published meshes
Geometry.BODY_NAME = "LeverBody"
-- THE GROUP THAT MOVES. The shotgun's is `Barrels` and it hinges; the Rigby's is `Bolt` and it
-- slides; this one is the finger `Lever` and it SWINGS THROUGH AN ARC -- a third kind, and both
-- halves of the reason are in `Geometry.leverThrow` below and in `Viewmodel.poseHands` (design 7.1).
Geometry.CYCLE_GROUP_NAME = "Lever"
Geometry.CYCLE_KIND = "lever"

-- DOES THIS GUN PUT LOOSE ROUNDS IN THE PLAYER'S HANDS? (task 224, design 7.3.) The shotgun does:
-- it is broken over the arm and fed two shells by hand, and `Viewmodel.loadingAt` and
-- `Viewmodel.shells` draw exactly that. This gun does not -- its cartridges go through a gate on the
-- receiver's right flank, which is a drawn feed nobody has built (queued as 224a) -- and neither
-- does the Rigby, which swaps a box.
--
-- IT IS A DECLARED FACT ABOUT THE GUN AND NOT A BORROWED PREDICATE. Both drawn paths used to be
-- gated on `config.MAGAZINE_SWAP ~= nil`, which answers *"does this gun swap a box"* and was
-- standing in for this question because on the two shipped guns the two answers agree. They do not
-- agree here: this gun has no magazine, so that predicate would say "draw them" -- and underneath
-- it `chamberOffset` is `Gun.chamber(barrel, Shotgun.CONFIG)`, the SHOTGUN's chamber mouths at the
-- shotgun's 4.4-stud layout. A red 12-gauge hull would flip out of a .45-70 after every shot.
Geometry.HAND_FED_SHELLS = false

-- The same three keys the WORLD lever wears (`Weapons.ROWS.lever.ASSET_KEYS`): unlike model B, which
-- has a world gun and a viewmodel gun, this rifle is ONE model and both draw it.
Geometry.ASSET_KEYS = table.freeze({ "lever.action", "lever.stock", "lever.lever" })

Geometry.MESH_KEYS = table.freeze({
	Action = "lever.action",
	Stock = "lever.stock",
	Lever = "lever.lever",
})

-- THE SIGHTS ARE THE MODEL'S OWN, AND THEY MEASURE LEVEL. This is the whole difference from the
-- Rigby, whose twelve nodes carry no sight node at all and whose bead is therefore DRAWN
-- (`Rifle.Geometry`'s `BEAD_DIAMETER` block). This rifle is sold with ghost-ring irons on a rail and
-- they are inside the `action` upload. RE-MEASURED in task 227, by
-- `driven-hunt-runs/227-sights.py`, which imports `tools/gltf_split.py` and uses its frame -- the
-- same one frame task 224 used:
--
--   the rear notch SHOULDERS  y +0.2301  at z +0.3174  (`Sights`, the tops of the two ears)
--   the rear notch FLOOR      y +0.2226  at z +0.3174  (the slot cut between them, 0.0075 deep)
--   the front blade TIP       y +0.1903  at z -1.9135  (`Front sight`, at the muzzle)
--
-- TASK 224 MEASURED THE REAR SIGHT WRONG AND THIS IS WHAT IT COST (Karen, 2026-10-21: *"Aiming with
-- lever i terrible and broken"*). `t224/measure.py` took `min(y)` over the whole `Sights` node and
-- labelled it "the rear notch floor": `min(y)` is where the sight assembly SITS ON THE RAIL, not
-- the notch. That put the rear reference at y +0.1901 -- 0.0400 studs below the shoulders -- and
-- since the front blade's TIP happens to sit at +0.1903, the two numbers agreed to 0.0002 and the
-- header claimed **0.0055 degrees from level**. Two different features of two different parts,
-- level with each other by coincidence. The real line is the one below.
--
-- THE SIGHT LINE IS THE SHOULDERS TO THE BLADE TIP, which is how an open sight is actually used:
-- the top of the front post is levelled with the tops of the rear notch's ears and centred in the
-- slot. Measured: -0.03983 studs over 2.2309 of separation = **-1.0229 degrees**, nose-down from
-- the gun's own Z axis. It is NOT level, and that is a fact about this bought model rather than an
-- error -- which is exactly why `Geometry.sight` below answers a ROTATED frame instead of a
-- position: the eye is laid ON that line and looks ALONG it, so both sights land on the camera axis
-- whatever the model's own slope is. Aligning the eye with the notch FLOOR instead was tried and
-- photographed (`.screenshots/227-...`): the blade tip then hides exactly behind the notch's bottom
-- edge, because floor and tip project to the same point.
--
-- THE FRONT BLADE IS WHERE `Geometry.sight` LAYS THE EYE, and it is placed ON THE GUN'S CENTRE LINE
-- (x = 0) rather than at the blade's measured x of -0.0014, because the bullet leaves at x = 0
-- (`Lever.CONFIG.MUZZLE_OFFSET`) and a sight that disagrees with the bore is a sight that lies.
-- That 0.3 mm is the MESH sitting off-centre in the Handle, not an aiming error -- the rule
-- `Rifle.Geometry.beadOffset` already states.
local SIGHT_FRONT_Y = 0.1903
local SIGHT_FRONT_Z = -1.9135
-- The SHOULDERS, not the floor: see the block above. The floor is kept beside them because the slot
-- is what the blade sits IN, and a spec that wants to know the notch is open needs its depth.
local SIGHT_REAR_Y = 0.2301
local SIGHT_REAR_Z = 0.3174
local SIGHT_NOTCH_FLOOR_Y = 0.2226

-- THE FRONT BEAD, DRAWN ON THE BLADE (task 242). KAREN, 2026-10-22, verbatim: *"also aiming improved
-- a bit"*, after the two sentences about the semi-automatic's red dot.
--
-- TASK 227'S ALIGNMENT IS NOT WHAT IS WRONG, AND IT WAS MEASURED BEFORE ANYTHING WAS CHANGED: in the
-- Forest Test, aimed, the front blade tip and the rear notch shoulders BOTH project to (473.5, 392.5)
-- on a 947 x 785 frame whose centre is (473.5, 392.5) -- zero pixels of error, in the place Karen
-- plays (`.screenshots/242-4-before-lever.png`, `driven-hunt-runs/242-sight.luau`). The gun is not
-- low, it is not canted, and the right hand is 0.640 studs BEHIND the eye, so no glove is in the way.
--
-- WHAT IS WRONG IS THAT THERE IS NOTHING TO FIND. Read off that same frame, row by row: the notch
-- opens about 14 px and the blade inside it is 3 px -- both of them dark steel, against a wood of
-- trees that is also dark. The sight picture is CORRECT and INVISIBLE, which on a screen is the same
-- complaint as a broken one.
--
-- SO THE BLADE GETS A BEAD, which is what the real rifle has: a Marlin 1895 SBL ships with an ORANGE
-- FIBRE-OPTIC front sight for exactly this reason, and this repo already draws one on the Rigby for
-- a neighbouring reason (`Rifle.Geometry`'s `BEAD_DIAMETER`: the model has a band and no bead). That
-- is the pattern borrowed, at its second instance, rather than anything invented (rule 2).
--
-- 0.020 STUDS IS SIZED AGAINST THE NOTCH IT HAS TO SIT IN, not picked. At the shipped 2.85-stud
-- relief it subtends 2*atan(0.010/2.85) = 0.40 degrees, which is 6.3 px of that 785-px frame at
-- FOV 50 -- a little under half the 14 px the notch opens, so there is daylight on BOTH sides of it,
-- which is the whole of how an open sight is read. Bigger fills the notch and the picture stops
-- being a picture.
--
-- IT IS CENTRED ON `beadOffset` AND THAT IS THE POINT: the eye is laid on that line by
-- `Mode.aimOffset`, so the bright thing the eye finds IS the point the shot leaves on. One
-- expression, which is this file's rule for the front sight already.
--
-- `Neon` IS A MATERIAL THAT RENDERS BRIGHT AND NOT A LIGHT SOURCE (Roblox emits light only from
-- `PointLight`/`SpotLight`/`SurfaceLight`), which is the semi-automatic's dot's own note: it costs
-- the scene nothing and it reads in shade, which is where a fibre sight earns its keep.
local BEAD_DIAMETER = 0.020
local BEAD_COLOR = Color3.fromRGB(255, 122, 24)

-- THE LEVER'S PIVOT: the boss where the loop pins into the receiver, taken as the centroid of the
-- lever node's forward-most 8% in z that also lies in its upper half -- which is the material around
-- the pin and nothing else (72 vertices). The loop turns about this point and about nothing else.
local LEVER_PIVOT = Vector3.new(0, -0.0660, 0.1944)
-- WHERE THE RIGHT HAND CLOSES ON THE LOOP: its OUTER APEX, the centroid of the 52 vertices within
-- 0.02 of the point furthest from the pivot. Reach 0.6913 from the pivot.
--
-- THE FIRST CUT FITTED A CYLINDER TO THE LOWEST QUARTER OF THE LOOP and got a mean residual of
-- 0.0206 on a radius of 0.0565 -- which is a curved sweep refusing to be a cylinder, not a bar. A
-- loop is not a knob: the Rigby's bolt handle IS a ball on a stem and fits a sphere to 0.001, and
-- claiming the same kind of fit here would have been a number that looks measured and is not.
local LEVER_GRIP = Vector3.new(0, -0.3592, 0.8204)
-- How thick the bar is where the hand sits: the smaller of the loop's two cross-section extents
-- around the apex, halved. `HandAssets.GRIP_STUDS` is the hole in the closed glove.
local LEVER_GRIP_RADIUS = 0.0443

-- THE STOCK'S WRIST (task 188's four tolerances, measured the same way on this gun). The narrowest
-- cross-section of the stock between the receiver's rear (z +0.9645) and the comb, taken as the
-- centre of 0.05-stud slices: narrowest at z +1.0895 (0.0935 studs across, against 0.1205 at
-- z +0.9895 and 0.1152 at z +1.1895). The AXIS is the least-squares line through the five slice
-- centres: dy/dz = +0.2922, which is 16.3 degrees of comb rise.
--
-- A HAND GRIPS A WRIST, NOT A POINT, which is why the axis is published beside the point:
-- `poses.json` is checked against the LINE. Task 188 exists because a pose 0.158 along the axis put
-- the hand on the comb and the spec passed anyway.
local GRIP_WRIST = Vector3.new(0, -0.1869, 1.0895)
local GRIP_WRIST_DIR = Vector3.new(0, 0.2805, 0.9599).Unit
local GRIP_RADIUS = 0.0468 -- half the narrowest slice
local GRIP_HALF_LENGTH = 0.1042 -- half the holdable span, along the axis

-- THE LOADING GATE, on the receiver's RIGHT flank: `slide` is the only node in the bought file lying
-- entirely on one side of the centre line (x +0.0169..+0.0412). Nothing reads this yet -- the drawn
-- gate feed is queued as 224a (design 7.4) -- and it is recorded here, measured, so that task starts
-- from a number rather than from a guess.
local GATE_AT = Vector3.new(0.0291, 0.0288, 0.0985)

local STEEL_MATERIAL = Enum.Material.SmoothPlastic -- `Metal` mirrors the sky; see `Gun`'s own note

local function span(low: number, high: number): (number, number)
	return high - low, (high + low) / 2
end

-- Every measurement this gun has, scaled by the Handle's length so that a different `HANDLE_SIZE.Z`
-- moves the whole gun together. 4.0 is what the meshes were baked at, so at 4.0 the numbers below
-- are exactly the measured ones.
function Geometry.layout(config)
	local total = (config and config.HANDLE_SIZE or Lever.CONFIG.HANDLE_SIZE).Z
	local k = total / 4.0
	local stockW, stockX = span(-0.1046 * k, 0.1046 * k)
	local stockH, stockY = span(-0.5874 * k, 0.0461 * k)
	local stockL, stockZ = span(0.5491 * k, 2.0 * k)
	local actionW, actionX = span(-0.0706 * k, 0.0696 * k)
	local actionH, actionY = span(-0.3167 * k, 0.2301 * k)
	local actionL, actionZ = span(-2.0 * k, 0.9645 * k)
	local leverW, leverX = span(-0.0192 * k, 0.0191 * k)
	local leverH, leverY = span(-0.3949 * k, 0.0138 * k)
	local leverL, leverZ = span(0.1749 * k, 0.8357 * k)
	return table.freeze({
		total = total,
		half = total / 2,
		muzzleZ = -total / 2,
		meshCentreY = MESH_CENTRE_Y * k,
		sightFrontY = SIGHT_FRONT_Y * k,
		sightFrontZ = SIGHT_FRONT_Z * k,
		sightRearY = SIGHT_REAR_Y * k,
		sightRearZ = SIGHT_REAR_Z * k,
		sightNotchFloorY = SIGHT_NOTCH_FLOOR_Y * k,
		beadDiameter = BEAD_DIAMETER * k,
		gateAt = GATE_AT * k,
		stock = { size = Vector3.new(stockW, stockH, stockL), at = Vector3.new(stockX, stockY, stockZ) },
		action = { size = Vector3.new(actionW, actionH, actionL), at = Vector3.new(actionX, actionY, actionZ) },
		lever = { size = Vector3.new(leverW, leverH, leverL), at = Vector3.new(leverX, leverY, leverZ) },
		-- THE GENERIC PAIR THE VIEWMODEL READS (design 7.2). `buildNewGun` sizes and places the
		-- moving group from `at.barrelLength`/`at.barrelZ` or `at.bolt.size.Z`/`at.bolt.at.Z` --
		-- both of which are a SPECIFIC gun's names. These two say the same thing for any gun, and
		-- they are DERIVED from this weapon's own `lever` box above, so there is one measurement
		-- here and not two that can drift. Folding them back into `Gun` and `Rifle.Geometry` is
		-- queued ("before release").
		cycleLength = leverL,
		cycleZ = leverZ,
	})
end

-- WHICH SIGHT THIS ROW CARRIES. This gun has exactly one configuration -- iron sights, on the rail,
-- inside the action upload -- so the default is `"bead"` where the Rigby's is `"scope"`, and no
-- piece is filtered on it. The function is here because the function SET is the contract: a caller
-- that asks all three geometries the same question must get an answer from each.
function Geometry.sightKind(config): string
	return (config and config.SIGHT) or "bead"
end

-- WHERE THE FRONT SIGHT IS, AND THE ONE PLACE THAT DECIDES IT -- the rule the other two guns already
-- keep (`Gun.beadOffset`, `Rifle.Geometry.beadOffset`): the point the eye is laid on and the thing
-- the eye sees must come from one expression, because nothing in the game compares two copies.
function Geometry.beadOffset(config): Vector3
	local at = Geometry.layout(config)
	return Vector3.new(0, at.sightFrontY, at.sightFrontZ)
end

-- WHERE THE EYE IS LAID, AND WHICH WAY IT LOOKS (task 227). NOT identity rotation, and that is the
-- whole fix: `Mode.aimOffset` puts this frame on the camera's axis and turns the gun so that THIS
-- FRAME's -Z runs down the screen's centre. So a frame whose -Z is the gun's own SIGHT LINE --
-- rear notch shoulders to front blade tip -- lands both sights on the screen centre, by
-- construction, with no cheek angle and nothing tuned by eye. A frame with identity rotation
-- instead lands the BLADE on the centre and leaves the notch wherever the model's -1.02 degrees of
-- slope puts it, which is 1.02 degrees high: the picture Karen called broken.
--
-- IT ANSWERS A LINE, NOT A POINT, and `eyeReliefStuds` then says how far back along that line the
-- eye sits. `poses.json` carries 2.85 for this gun: 2.2313 of it is blade-to-notch, so the eye is
-- 0.619 studs (about 16 cm at this gun's scale) behind the notch -- far enough back that the right
-- glove, posed at z +1.203, stays behind the lens instead of filling it (measured at 3.15, which
-- put the glove 0.03 studs IN FRONT of the eye).
--
-- The up vector is the default (0, 1, 0) and the line lies in the gun's own YZ plane, so the frame
-- carries no roll: the rifle is not tilted.
function Geometry.sight(config): CFrame
	local at = Geometry.layout(config)
	local front = Geometry.beadOffset(config)
	local rear = Vector3.new(0, at.sightRearY, at.sightRearZ)
	return CFrame.lookAt(front, front + (front - rear).Unit)
end

function Geometry.muzzle(config): CFrame
	local at = Geometry.layout(config)
	return CFrame.new(0, 0.12 * (at.total / 4.0), at.muzzleZ)
end

-- THE LEVER'S PIVOT, in the gun's frame. `Camera.Viewmodel.hinge` reads this before it branches, and
-- a caller written for the shotgun gets a point on the gun rather than nil.
function Geometry.hinge(config): Vector3
	local at = Geometry.layout(config)
	return LEVER_PIVOT * (at.total / 4.0)
end

-- HOW FAR, AND WHICH WAY, THE LOOP SWINGS. `progress` is 0 at rest and 1 at full throw; the CFrame
-- is in the gun's own frame and `Camera.Viewmodel.hinge`'s `"lever"` path is its only caller.
--
-- IT IS HERE, AND NOT INLINE IN THE VIEWMODEL, FOR THE REASON TASK 188 BOUGHT: a sign nobody can
-- see is a sign that ships wrong. `Viewmodel.hinge`'s break-action branch is
-- `CFrame.Angles(-math.rad(angle), 0, 0)`, and that NEGATIVE rotation carries a loop hanging below
-- and behind its pin UP AND TOWARD THE BUTT -- the opposite of opening. The throw is POSITIVE about
-- +X, and it was measured on the model rather than argued about: the loop's apex sits at
-- (-0.3592, +0.8204) and the pivot at (-0.0660, +0.1944), so rotating it by
--
--   30 deg -> down 0.253, forward 0.225      60 deg -> down 0.360, forward 0.546
--   45 deg -> down 0.328, forward 0.379      70 deg -> down 0.357, forward 0.660  (coming back UP)
--
-- which is down and forward, and says that ~60 degrees is where the loop stops going down. That is a
-- real Marlin's throw, and it is the seed for `cycle.openDeg` in `poses.json`.
--
-- IT TAKES THE ANGLE RATHER THAN READING IT, because the two live in different tables: the pivot is
-- the WEAPON ROW's (it scales with `HANDLE_SIZE`) and the throw is the POSE DATA's (`cycle.openDeg`,
-- which the Director tunes live). `progress` is clamped rather than trusted -- this is the one place
-- a throw angle exists, and a caller that passed 1.4 would bury the loop in the stock.
function Geometry.leverThrow(config, throwDeg: number, progress: number): CFrame
	local pivot = CFrame.new(Geometry.hinge(config))
	local degrees = (throwDeg or 0) * math.clamp(progress, 0, 1)
	return pivot * CFrame.Angles(math.rad(degrees), 0, 0) * pivot:Inverse()
end

-- THE LOOP'S GRIP BAR, in the gun's frame, with the lever CLOSED. The point the right hand closes
-- on: `poses.json`'s `cycle.hand.grip` puts `HandAssets.GRIP_STUDS` on it, and the hand is then
-- carried by the lever's own transform -- so the hand holds the loop wherever the loop has got to,
-- and "the lever moves with the hand" is true by construction rather than by two numbers agreeing.
function Geometry.leverGripOffset(config): Vector3
	local at = Geometry.layout(config)
	return LEVER_GRIP * (at.total / 4.0)
end

function Geometry.leverGripRadius(config): number
	local at = Geometry.layout(config)
	return LEVER_GRIP_RADIUS * (at.total / 4.0)
end

-- THE STOCK'S WRIST: a POINT on it and the DIRECTION it runs. The hip and the aimed poses put the
-- hand's own grip point on this LINE -- a hand slides a little along a wrist and is still holding
-- it, but a hand off the line is a hand beside the gun. SAME NAMES as the Rigby's, so one spec
-- helper checks both guns' hip holds.
function Geometry.gripOffset(config): Vector3
	local at = Geometry.layout(config)
	return GRIP_WRIST * (at.total / 4.0)
end

function Geometry.gripAxis(config): Vector3
	local _ = config -- a direction does not scale
	return GRIP_WRIST_DIR
end

function Geometry.gripRadius(config): number
	local at = Geometry.layout(config)
	return GRIP_RADIUS * (at.total / 4.0)
end

function Geometry.gripHalfLength(config): number
	local at = Geometry.layout(config)
	return GRIP_HALF_LENGTH * (at.total / 4.0)
end

-- How far ALONG the wrist a point sits, signed, from `gripOffset`. Positive is toward the butt.
function Geometry.alongGripAxis(config, point: Vector3): number
	return (point - Geometry.gripOffset(config)):Dot(Geometry.gripAxis(config))
end

-- How far a point is from the wrist's line. The one expression that answers "is the hand on the
-- grip", so the spec and any future tool cannot disagree about it.
function Geometry.offGripAxis(config, point: Vector3): number
	local along = point - Geometry.gripOffset(config)
	local dir = Geometry.gripAxis(config)
	return (along - dir * along:Dot(dir)).Magnitude
end

-- Every piece of the first-person lever rifle, in build order. Pure.
--
-- THREE MESHES AND ONE DRAWN BEAD (task 242). The three uploads carry everything this rifle is --
-- its sights are on its rail and its magazine is a tube under its barrel, both inside the `action`
-- group -- so nothing about the GUN is invented here. What is drawn is the one thing a screen needs
-- and a model cannot give: a bright front bead, for the reason measured at `BEAD_DIAMETER` above.
-- The Rigby draws one too, and for a neighbouring reason (its model has a band and no bead).
function Geometry.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local meshAt = CFrame.new(0, at.meshCentreY, 0) * CFrame.Angles(0, math.rad(Geometry.MESH_ROTATION_DEG), 0)
	local look = (config and config.LOOK) or Lever.CONFIG.LOOK
	local sight = Geometry.sightKind(config)
	-- ONE LIST, FILTERED BY THE ROW'S SIGHT (task 143), AT ITS THIRD INSTANCE -- the Rigby's and the
	-- semi-automatic's `pieces` are the same eight lines. It arrives with the bead (task 242), and
	-- NOT before it: until this task nothing in this list was sight-specific, so a filter would have
	-- been a field nobody read -- *"an argument nobody reads is an argument nobody checked"*.
	local function wanted(piece): boolean
		if piece.skipFor ~= nil and piece.skipFor == sight then
			return false
		end
		if piece.onlyFor ~= nil and piece.onlyFor ~= sight then
			return false
		end
		return true
	end
	local kept: { Piece } = {}
	for _, piece in ipairs({
		{
			name = "Stock",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Stock,
			meshOffset = meshAt,
			size = at.stock.size,
			offset = CFrame.new(at.stock.at),
			color = look.wood,
			-- GREY LAMINATE, NOT WALNUT: an 1895 SBL's stock is layered birch, which is why the
			-- fallback colour is grey and why `asset_prep` classified the whole group as steel
			-- (its pixels are below the wood rule's saturation floor -- research note section 8).
			-- `Wood` is still the right MATERIAL: laminate is wood, and it is not shiny.
			material = Enum.Material.Wood,
			shape = Enum.PartType.Block,
		},
		{
			-- THE BODY: receiver, barrel, rail, both sights, the magazine tube and its cap, the
			-- fore-end, both swivels, the trigger, the hammer, the breech bolt and the loading gate.
			-- Worn as `Model`, which is the piece that must be there for the gun to count as dressed
			-- (`Hardware.wearsMesh`).
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
			-- THE FRONT BEAD. Drawn, bright, and centred on `beadOffset` -- the ONE expression that
			-- says where the front sight is, so the thing the eye finds and the point the eye is laid
			-- on cannot drift apart.
			--
			-- `onlyFor = "bead"` IS THIS GUN'S WHOLE SIGHT CONFIGURATION TODAY (`Geometry.sightKind`
			-- answers `"bead"` and no shipped row says otherwise), and it is written anyway, in task
			-- 143's own filter: the day a lever row carries a scope, the bead goes with the irons in
			-- one list and nothing else changes.
			name = "Bead",
			group = "body" :: Gun.Group,
			onlyFor = "bead",
			size = Vector3.new(at.beadDiameter, at.beadDiameter, at.beadDiameter),
			offset = CFrame.new(Geometry.beadOffset(config)),
			color = BEAD_COLOR,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
		},
		{
			-- THE PIECE THAT MOVES: the large-loop finger lever, which on a Marlin IS the trigger
			-- guard -- which is why the bought file has no separate guard node. `Gun.Group`'s second
			-- value is the moving group whatever the gun calls it.
			name = Geometry.CYCLE_GROUP_NAME,
			group = "barrels" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Lever,
			meshOffset = meshAt,
			size = at.lever.size,
			offset = CFrame.new(at.lever.at),
			color = look.lever,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
	}) do
		if wanted(piece) then
			table.insert(kept, piece :: any)
		end
	end
	return kept
end

function Geometry.partCount(config): number
	return #Geometry.pieces(config) + 2
end

return Geometry
