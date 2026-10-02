--!strict
-- Gun: the FIRST-PERSON shotgun's geometry, as data. Pure -- it creates no Instance, reads no
-- service and holds no state, so a spec asserts every proportion with no Tool, no character and no
-- camera. `Camera.Viewmodel` is the one thing that builds it (CLAUDE.md rule 3).
--
-- IT IS MODEL B SINCE TASK 105, AND THAT IS KAREN'S DECISION. On 2026-10-02 she looked at the
-- exact-geometry gun tasks 99 to 103 built -- round Cylinder barrels, a drawn action, drawn bores --
-- and said "bad": beside the reference frame it reads as Roblox blocks. She then picked a
-- professional model and downloaded it:
--
--   "Double Barrel Shotgun" by Ryan_Nein
--   https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd
--   CC-BY-4.0 -- commercial use allowed, the author must be credited. CREDITS.md carries the credit
--   the licence asks for, and so does every row of this gun in `ServerStorage.Assets`.
--
-- The exact geometry is archived, not deleted (rule 7): `backups/task-105/`.
--
-- SO THIS FILE NO LONGER DRAWS A GUN. It says WHERE MODEL B'S OWN PARTS ARE, in the Handle's frame,
-- and every number in it was MEASURED off the model by `tools/gltf_split.py probe` rather than
-- chosen -- the bore line, the breech, the knuckle the barrels hinge on, the two groups' boxes. The
-- gun on screen is two MeshParts and one bead.
--
-- TWO MESHPARTS, BECAUSE A BREAK ACTION HINGES and one MeshPart cannot. `tools/gltf_split.py` splits
-- the model BY NODE at the hinge -- the BARREL GROUP is the two tubes and the chequered forend,
-- which is what swings; the FRAME GROUP is the action, stock, trigger, guard, top lever and safety,
-- which does not -- and gives both the WHOLE gun's bounding box with two anchor triangles, so they
-- import at one size and one origin and assemble at one CFrame with no measured per-piece offset
-- (the trick task 96 already used on Karen's gun).
--
-- AND IT STILL DRAWS A GUN WITH NO UPLOAD. A group whose mesh the server did not publish is drawn as
-- its own measured box in its own colour, exactly as the wood was before it: a gun whose upload
-- failed is a plain gun, not a hole where a gun should be. Each mesh piece in `Gun.pieces` holds
-- both answers: `meshKey` plus `meshOffset`, and the `size`/`shape`/`color` of the box beside it.
--
-- NO BORE DISCS, AND THAT WAS LOOKED AT (rule 5). Task 99 drew four near-black discs because a
-- Roblox Cylinder is solid at both ends and a solid tube has no opening to look into. Model B's
-- tubes are MODELLED OPEN at both ends -- `render_three-quarter.png` and `render_muzzle.png` of the
-- prep run both show two round dark openings with a thin wall of steel round them -- so the discs
-- would now be four discs plugging holes that are already there. They went with the rest of the
-- exact geometry.
--
-- IT MOVES NO NUMBER A SHOT DEPENDS ON. `Shotgun.CONFIG.HANDLE_SIZE`, `MUZZLE_OFFSET`, `GRIP` and
-- the hitbox are untouched: the model is scaled UNIFORMLY so that its own length is
-- `HANDLE_SIZE.Z`, which is the one number this gun's scale is pinned to. What moved is the gun's
-- own cross-section, and it moved toward life: model B's tubes are 0.078 studs across (21.7 mm at
-- this scale, which is a 12-gauge) where the drawn ones were 0.145.
--
-- Note: docs/research/2026-10-01-exact-metal-gun.md (why the gun stopped being one AI mesh)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Gun = {}

-- WHICH GROUP A PIECE BELONGS TO, and it is the whole of the break-open. "body" is bolted to the
-- action and never moves; "barrels" swings down about the hinge, and everything in it goes with it
-- -- the two tubes, the forend and the bead, exactly as on a real gun.
export type Group = "body" | "barrels"

export type Piece = {
	name: string,
	group: Group,
	size: Vector3,
	offset: CFrame, -- in the Handle's own frame: -Z is the muzzle, +X right, +Y up
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType,
	reflectance: number?,
	-- THE MANIFEST KEY OF THE MESH THIS PIECE REALLY IS, when one is published. `size`, `shape` and
	-- `color` above are then the FALLBACK -- the box drawn in its place when the upload did not
	-- load -- and `meshOffset` is where the mesh goes instead, because the two need not be the same
	-- place: a mesh carries the whole gun's box and sits at its centre, while the fallback box is
	-- only that group's own and sits at the group's centre.
	meshKey: string?,
	meshOffset: CFrame?,
}

-- ---------------------------------------------------------------- the numbers
--
-- EVERY ONE OF THESE WAS MEASURED, by `python tools/gltf_split.py probe --in <model-b>`, off the
-- model itself after the tool had put it in this frame. The run's own `split-report.json` holds the
-- same numbers; these are the ones the game needs.
--
-- Z AND X ARE FRACTIONS OF THE GUN'S LENGTH, because they are proportions of the model and they must
-- follow `HANDLE_SIZE.Z` if it ever changes. Y IS IN STUDS ABOVE OR BELOW THE BORE LINE for the same
-- reason the other way round: the bore line is `BARREL_Y`, a number `Shotgun.CONFIG` already fixes
-- (`BARREL_RISE_STUDS`), and the splitter aligned the model to it.

-- THE BORE LINE. The same 0.12 `tools/gltf_split.py`'s model-b plan aligned the two tubes' common
-- axis to, and the same `Shotgun.CONFIG.BARREL_RISE_STUDS` the world gun's flash already uses.
local BARREL_Y = 0.12

-- 0.617 of the gun is barrel, against the 28-in-of-45 spec sheet's 0.622: this model is a real
-- gun's proportions, which is why it was chosen.
Gun.BARREL_FRACTION = 0.61739355
-- One 12-gauge tube: 0.0779 studs across, which is 21.7 mm at this gun's scale.
local BARREL_DIAMETER_T = 0.01771191
-- ...and the two tubes' centres, half the pair's width in from the outside.
local BARREL_HALF_GAP_T = 0.00880636

-- THE KNUCKLE: the rounded front face of the action, which is the surface a break-action's barrels
-- really turn on. Measured as a face at one Z spanning a range of Y, so the pin is its centre set
-- back by its own radius -- see `Gun.hinge`.
local KNUCKLE_FACE_Z_T = 0.06645702
local KNUCKLE_CENTRE_ABOVE_BORE_T = -0.01565909
local KNUCKLE_RADIUS_T = 0.00912750

-- THE TWO GROUPS' OWN BOXES, which are what is drawn when a mesh did not load. Half-width is the
-- whole gun's, because both groups are exactly as wide as the barrel pair.
local HALF_WIDTH_T = 0.01766227
local BARREL_GROUP_LOW_ABOVE_BORE_T = -0.03416273 -- the forend's underside
local FRAME_GROUP_LOW_ABOVE_BORE_T = -0.14151932 -- the toe of the butt
-- Both groups stop at the barrel tops: the action's top is level with the tubes it carries.
local GROUP_HIGH_ABOVE_BORE_T = BARREL_DIAMETER_T / 2

-- WHERE THE WHOLE MODEL'S BOUNDING BOX IS CENTRED, which is where Roblox puts a MeshPart's pivot and
-- therefore where BOTH group meshes are placed. X and Z are zero by construction -- the splitter
-- centres the gun across and puts the muzzle at -HANDLE_SIZE.Z/2 -- so only Y is a measurement.
local MESH_CENTRE_ABOVE_BORE_T = -0.06633159

-- HOW BIG EACH GROUP MESH IS, IN ITS OWN AXES, and the long axis is X: `tools/asset_prep.py`
-- measured "long axis X" on both groups, which is the same thing it measured on Karen's gun -- and
-- that is why `Gun.MESH_ROTATION_DEG` below is the same quarter turn her rows already carry.
-- `ServerStorage.Assets` reads this, so the gun's geometry decides the scale rather than a number
-- copied into the manifest.
Gun.MESH_SIZE_STUDS = Vector3.new(
	Shotgun.CONFIG.HANDLE_SIZE.Z,
	0.15037549 * Shotgun.CONFIG.HANDLE_SIZE.Z,
	2 * HALF_WIDTH_T * Shotgun.CONFIG.HANDLE_SIZE.Z
)
-- THE SHELL'S, by the same rule and from the same run: the artist's 12-gauge cartridge, at the gun's
-- own uniform scale, so it is the size it would really be in this gun's chambers.
Gun.SHELL_MESH_SIZE_STUDS = Vector3.new(0.13685, 0.065588, 0.065577)

-- THE NAMES THE VIEWMODEL LOOKS FOR, so neither side carries a literal the other could disagree
-- with (the reason `HandAssets` and `Assets.KEYS` exist).
Gun.BODY_NAME = "GunBody"
Gun.BARRELS_NAME = "Barrels" -- the SAME name the old mesh gun's barrel piece has, so
-- `Camera.Viewmodel.hinge` and the left hand's parent rule are one rule for both guns.
Gun.BARREL_GROUP_NAME = "BarrelGroup"
Gun.FRAME_GROUP_NAME = "FrameGroup"
-- The manifest key of each group's mesh. One key per hinge group, and nothing else: model B carries
-- its own forend and its own stock, so the separate wood keys tasks 99 to 103 used are retired.
Gun.MESH_KEYS = table.freeze({
	[Gun.BARREL_GROUP_NAME] = "gun.barrels",
	[Gun.FRAME_GROUP_NAME] = "gun.frame",
})
Gun.SHELL_KEY = "gun.shell"
-- WHERE THE SERVER PARKS THE GUN for the client to clone, the same arrangement the hands have
-- (`HandAssets.FOLDER_NAME`): `InsertService:LoadAsset` is server-only, so the server loads and
-- publishes and `Camera.Viewmodel` clones. Created at RUN TIME, never on disk -- ReplicatedStorage
-- is Rojo-owned and a folder parked there in Edit would be deleted at the next Connect.
Gun.FOLDER_NAME = "ViewmodelGun"
Gun.SHELL_TEMPLATE_NAME = "Shell"

-- HOW A GROUP MESH IS TURNED to lie on this gun. Both arrive with their LONG AXIS ALONG X (measured
-- by `tools/asset_prep.py`: "long axis X"), and this gun's long axis is Z with -Z the muzzle -- so a
-- quarter turn about Y lays it down. The sign is the one Karen's two halves already ship with
-- (`Assets.ROWS`, `rotationDeg = (0, 90, 0)`), because `tools/gltf_split.py` writes the model out in
-- the same convention on purpose: muzzle at the file's +X.
Gun.MESH_ROTATION_DEG = 90
-- The shell's mouth is at the file's +X too, by the same convention, so it takes the same turn.
Gun.SHELL_ROTATION_DEG = 90

-- THE SHELL'S BRASS RIM, which is what stands out of a chamber mouth and is the only part of a
-- seated shell a player can see. Kept from task 99 for the DRAWN shell, which is what is built when
-- no shell mesh is published.
Gun.SHELL_RIM_THICK = 0.003
-- A hair wider than the bore, so it COVERS the chamber mouth instead of sitting in it.
Gun.SHELL_RIM_DIAMETER = BARREL_DIAMETER_T * Shotgun.CONFIG.HANDLE_SIZE.Z * 0.72 + 0.006
-- ...and it stands this far proud of the breech face, so a seated shell is visible at all.
Gun.SHELL_RIM_PROUD = 0.005

-- THE BEAD, and it is the one piece of this gun that is still drawn. Model B has no rib and no bead
-- -- at 806 triangles for the whole gun there is nothing in it for a 3 mm ball -- and the bead is
-- the mark Karen aims with (`Camera.Mode.aimOffset` solves the aimed pose FROM it, and the
-- inspiration reference is bead aiming with no crosshair). So it is built here, on the gun's centre
-- line, at the muzzle.
local BEAD_DIAMETER = 0.026
-- WHERE IT SITS IS SOLVED, NOT PICKED: a side-by-side's bead sits in the notch between the two tube
-- tops, touching both. Two circles of radius r at +-g from the centre line, and a ball of radius b
-- on that line, touch when g^2 + (y - BARREL_Y)^2 = (r + b)^2. So the bead rests on the steel and
-- about a third of it stands above the tubes, which is what makes it findable down the barrels.

-- ---------------------------------------------------------------- the layout

-- WHERE EVERYTHING IS, along the gun's own axis, for a Handle of `config.HANDLE_SIZE`. One table, so
-- the pieces below and the public answers (`hinge`, `chamber`, `sight`) are built from the SAME
-- arithmetic rather than from two copies of it.
function Gun.layout(config)
	local total = (config and config.HANDLE_SIZE or Shotgun.CONFIG.HANDLE_SIZE).Z
	local half = total / 2
	local barrelLength = total * Gun.BARREL_FRACTION
	local muzzleZ = -half
	local breechZ = muzzleZ + barrelLength
	local barrelRadius = BARREL_DIAMETER_T * total / 2
	local beadY = BARREL_Y + math.sqrt((barrelRadius + BEAD_DIAMETER / 2) ^ 2 - (BARREL_HALF_GAP_T * total) ^ 2)
	return table.freeze({
		total = total,
		half = half,
		barrelLength = barrelLength,
		muzzleZ = muzzleZ,
		breechZ = breechZ,
		barrelZ = (muzzleZ + breechZ) / 2,
		barrelRadius = barrelRadius,
		barrelY = BARREL_Y,
		barrelTopY = BARREL_Y + barrelRadius,
		beadY = beadY,
		halfWidth = HALF_WIDTH_T * total,
		-- the knuckle, and the pin solved from it
		knuckleFaceZ = KNUCKLE_FACE_Z_T * total,
		knuckleRadius = KNUCKLE_RADIUS_T * total,
		hingeY = BARREL_Y + KNUCKLE_CENTRE_ABOVE_BORE_T * total,
		hingeZ = (KNUCKLE_FACE_Z_T + KNUCKLE_RADIUS_T) * total,
		-- the two groups' own boxes
		barrelGroupLowY = BARREL_Y + BARREL_GROUP_LOW_ABOVE_BORE_T * total,
		frameGroupLowY = BARREL_Y + FRAME_GROUP_LOW_ABOVE_BORE_T * total,
		groupHighY = BARREL_Y + GROUP_HIGH_ABOVE_BORE_T * total,
		meshCentreY = BARREL_Y + MESH_CENTRE_ABOVE_BORE_T * total,
	})
end

-- THE HINGE, and this is what makes the break-open real rather than a mesh tearing. A break-action's
-- barrels turn on the KNUCKLE -- the rounded front face of the action -- so the axis is the centre of
-- that round: the face's own mid-height, set back from the face by the round's own radius. Both
-- numbers are measured off model B's action, and the axis runs across the gun (X in the Handle's
-- frame).
function Gun.hinge(config): Vector3
	local at = Gun.layout(config)
	return Vector3.new(0, at.hingeY, at.hingeZ)
end

-- WHERE A SEATED SHELL'S RIM GOES: the chamber MOUTH -- on that tube's own bore line, a hair proud of
-- the breech face. It is the mouth and not a point down the chamber because a shell seated INSIDE an
-- opaque tube is a shell nobody can see.
--
-- `Gun.barrelOffset` is the one definition of this gun's bore line, so this module still does not
-- learn that the right barrel is +X; and `Gun.shellLayout` is the one definition of how far behind
-- its rim a shell's pivot sits, so the caller that PLACES the shell and the builder that DRAWS it
-- cannot disagree about where the rim ended up.
function Gun.chamber(barrel: number, config): CFrame
	local at = Gun.layout(config)
	local across = Gun.barrelOffset(barrel, config)
	return CFrame.new(across.X, across.Y, at.breechZ + Gun.SHELL_RIM_PROUD)
end

-- ONE DRAWN SHELL'S OWN LAYOUT along its length, in the shell's local frame: the red body, the brass
-- base behind it, and the brass rim behind that. Pure arithmetic over the two numbers the CAMERA
-- owns (`Camera.Config.SHELL_SIZE_STUDS` and `SHELL_BASE_FRACTION`), passed in rather than read,
-- because a shared module cannot require a client one.
--
-- X IS THE SHELL'S LENGTH, with the MOUTH forward at +X -- the same convention
-- `tools/gltf_split.py` writes the shell MESH in, so the drawn shell and the mesh one take the same
-- quarter turn and seat at the same place. `back` is the one number that seats it: how far BEHIND the
-- model's pivot (its Body part, which is what `PivotTo` places) the rim's outer face is.
function Gun.shellLayout(sizeStuds: Vector3, baseFraction: number)
	local baseLength = sizeStuds.Z * baseFraction
	local bodyLength = sizeStuds.Z - baseLength
	return table.freeze({
		bodyLength = bodyLength,
		baseLength = baseLength,
		diameter = sizeStuds.X,
		rimThick = Gun.SHELL_RIM_THICK,
		rimDiameter = Gun.SHELL_RIM_DIAMETER,
		-- Offsets from the SHELL'S centre, which is the frame the three parts are built in.
		bodyX = baseLength / 2,
		baseX = -bodyLength / 2,
		rimX = -(sizeStuds.Z / 2 + Gun.SHELL_RIM_THICK / 2),
		-- ...and from the PIVOT, which is the Body: half the shell, plus the half base the body is
		-- offset forward by, plus the rim itself.
		back = sizeStuds.Z / 2 + baseLength / 2 + Gun.SHELL_RIM_THICK,
	})
end

-- WHERE THE BEAD SITS, and the ONE place that decides it. The aimed pose is solved FROM this
-- (`Camera.Mode.aimOffset`), so a second copy of the arithmetic would let the mark a player follows
-- and the point the camera lines up drift apart.
function Gun.beadOffset(config): Vector3
	local at = Gun.layout(config)
	return Vector3.new(0, at.beadY, at.muzzleZ + BEAD_DIAMETER)
end

function Gun.sight(config): CFrame
	-- Identity rotation: in this frame (0, 0, -1) is already the muzzle direction, and the bead is on
	-- the gun's centre line, so the sight looks exactly where the barrels point.
	return CFrame.new(Gun.beadOffset(config))
end

-- WHERE THIS GUN'S OWN BORE LINE IS, per barrel, in the Handle's frame -- and it is the ONE
-- definition of it. `Shotgun.barrelMuzzleOffset` answers the same question for the world gun, whose
-- tubes are `BARREL_HALF_GAP_STUDS` = 0.09 apart; model B's are 0.0387 apart, because its tubes are a
-- real 12-gauge's and the drawn ones never were. The SIGN still comes from `Shotgun`, so "which tube
-- is barrel 1" has one owner in the whole repo and this module does not learn that it is +X.
function Gun.barrelOffset(barrel: number?, config): Vector3
	local total = (config and config.HANDLE_SIZE or Shotgun.CONFIG.HANDLE_SIZE).Z
	local sign = if Shotgun.barrelMuzzleOffset(barrel, config or Shotgun.CONFIG).X >= 0 then 1 else -1
	return Vector3.new(sign * BARREL_HALF_GAP_T * total, BARREL_Y, 0)
end

-- THE `Muzzle` ATTACHMENT, ON THE HANDLE'S AXIS, exactly where `Weapon.Hardware` puts it on every
-- other gun (`CFrame.new(config.MUZZLE_OFFSET)`). It is NOT on the bore line, and that is the whole
-- of task 99's round-1 finding 2: `Camera.Viewmodel.muzzle` adds the barrel's own rise to whatever
-- this attachment says, so a bore-line attachment counted the rise twice and drew the first-person
-- flash above the barrels rather than out of a tube.
function Gun.muzzle(config): CFrame
	local at = Gun.layout(config)
	return CFrame.new(0, 0, at.muzzleZ)
end

-- ---------------------------------------------------------------- the pieces

-- `Enum.Material.Metal` IS THE REASON THE GUN WAS BLUE, AND IT IS MEASURED (task 100, rule 5).
-- Roblox's `Metal` is a conductor: its specular response is the ENVIRONMENT multiplied by the
-- albedo, and over an open field the environment is the sky. `SmoothPlastic` keeps a narrow white
-- specular lobe and does not mirror the sky. It is what the FALLBACK boxes are made of; a published
-- group mesh brings the artist's own maps and needs no material opinion from here.
local STEEL_MATERIAL = Enum.Material.SmoothPlastic

-- The colours. These are now the FALLBACK's -- what is drawn when an upload did not load -- plus the
-- bead, which is drawn on every gun. Model B's own colours are in its textures.
Gun.LOOK = table.freeze({
	-- Neutral dark grey, not blue: the target frame's barrels are a flat dark grey (task 100).
	blued = Color3.fromRGB(26, 27, 30),
	-- A dark case-hardened grey, measured from the reference frame's top strap (task 103).
	action = Color3.fromRGB(62, 63, 66),
	bead = Color3.fromRGB(198, 158, 82),
	-- Walnut, matched to the stock's lit pixels in the task 102 reload capture.
	wood = Color3.fromRGB(104, 64, 38),
})

-- Every piece of the first-person gun, in build order. Pure.
--
-- THREE PIECES, AND TWO OF THEM ARE MESHES. What used to be twenty-odd drawn parts is model B's own
-- two halves plus the bead it has not got.
function Gun.pieces(config): { Piece }
	local at = Gun.layout(config)
	-- BOTH MESHES SIT AT THE SAME PLACE, because `tools/gltf_split.py` gave both the WHOLE gun's
	-- bounding box: Roblox puts a MeshPart's pivot at its box's centre, so one offset places both and
	-- there is no per-piece number to get wrong. The quarter turn lays the model's long axis down the
	-- gun.
	local meshAt = CFrame.new(0, at.meshCentreY, 0) * CFrame.Angles(0, math.rad(Gun.MESH_ROTATION_DEG), 0)
	local pieces: { Piece } = {
		{
			name = Gun.BARREL_GROUP_NAME,
			group = "barrels" :: Group,
			meshKey = Gun.MESH_KEYS[Gun.BARREL_GROUP_NAME],
			meshOffset = meshAt,
			-- THE FALLBACK: the barrel group's own measured box, in its own place. A plain dark bar
			-- under the eye is a gun; nothing at all is a bug nobody can see.
			size = Vector3.new(at.halfWidth * 2, at.groupHighY - at.barrelGroupLowY, at.breechZ - at.muzzleZ),
			offset = CFrame.new(0, (at.groupHighY + at.barrelGroupLowY) / 2, (at.breechZ + at.muzzleZ) / 2),
			color = Gun.LOOK.blued,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
			reflectance = 0,
		},
		{
			name = Gun.FRAME_GROUP_NAME,
			group = "body" :: Group,
			meshKey = Gun.MESH_KEYS[Gun.FRAME_GROUP_NAME],
			meshOffset = meshAt,
			size = Vector3.new(at.halfWidth * 2, at.groupHighY - at.frameGroupLowY, at.half - at.knuckleFaceZ),
			offset = CFrame.new(0, (at.groupHighY + at.frameGroupLowY) / 2, (at.half + at.knuckleFaceZ) / 2),
			color = Gun.LOOK.action,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		-- THE BEAD RIDES WITH THE BARRELS, because a bead is a sight ON the barrels: with the gun
		-- broken open it belongs down at the muzzle where the barrels are, not floating where the
		-- muzzle used to be. `Enum.Material.Metal` is right for exactly this one piece -- the reason
		-- it ruined the barrels, that it mirrors the sky, is the reason it suits a tiny ball whose
		-- whole job is to catch the light and be seen.
		{
			name = "Bead",
			group = "barrels" :: Group,
			size = Vector3.new(BEAD_DIAMETER, BEAD_DIAMETER, BEAD_DIAMETER),
			offset = CFrame.new(Gun.beadOffset(config)),
			color = Gun.LOOK.bead,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Ball,
		},
	}
	return pieces
end

-- How many parts the drawn gun costs, counting the two envelopes the viewmodel adds (the Handle and
-- the barrel group's own). ASSERTED by `tests/server/gun.spec.luau`, so growth is a decision rather
-- than a drift.
function Gun.partCount(config): number
	return #Gun.pieces(config) + 2
end

return Gun
