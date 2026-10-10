--!strict
-- Rifle.Geometry: the DRAWN rifle, as data. The sibling of `src/shared/Gun/init.luau`, with the same
-- function set, so `Camera.Viewmodel.buildNewGun` can draw either weapon without learning which one
-- it has (`Weapons.geometry(id)` is the map).
--
-- EVERY BOX HERE WAS MEASURED OFF THE MODEL, in the Handle's own frame, by `tools/gltf_split.py
-- probe` on the Rigby before it was split (task 140). The frame: -Z is the muzzle, +X is right, +Y
-- is up, and the bore line sits at y = +0.12 by construction (`boreUpStuds`, the same number the
-- shotgun's `Gun.BARREL_Y` is).
--
--   stock   X[-0.1145 +0.0975]  Y[-0.5156 +0.1262]  Z[-0.8483 +2.2000]
--   action  X[-0.0945 +0.0668]  Y[-0.2058 +0.3370]  Z[-2.2000 +0.9092]   (barrel, receiver, guard)
--   bolt    X[-0.0640 +0.1150]  Y[+0.0167 +0.1887]  Z[+0.2034 +0.8258]   (body AND handle)
--   scope   X[-0.0919 +0.0864]  Y[+0.2003 +0.3941]  Z[-0.2081 +0.9291]   (tube, rings, turrets)
--
-- Those boxes are the FALLBACK -- what is drawn when an upload has not loaded yet -- and the four
-- published meshes all carry the WHOLE gun's bounding box (the anchor triangles `gltf_split` adds),
-- so one offset places every one of them and there is no per-piece number to get wrong. Same trick,
-- same reason, as model B's.
--
-- Design: docs/design/rifle.md (section 6.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Rifle = require(script.Parent)

local Geometry = {}

export type Piece = Gun.Piece

-- THE LONG AXIS OF THE MESH IS ITS OWN X, exactly as model B's is: `tools/asset_prep.py` measured
-- "long axis X" on all four groups. `ServerStorage.Assets` reads this, so the geometry decides the
-- scale rather than a number copied into the manifest.
local WHOLE = Vector3.new(4.4, 0.909786, 0.228694) -- the split report's `wholeBoxFileAxes.size`
Geometry.MESH_SIZE_STUDS = WHOLE
-- WHERE THAT BOX'S CENTRE SITS ON THIS GUN, in the Handle's frame: the model spans y -0.515645 to
-- +0.394142, so its centre is 0.0608 BELOW the Handle's origin. x and z are centred by construction
-- (the muzzle is at -2.2 and the butt at +2.2).
local MESH_CENTRE_Y = -0.060752

-- THE SAME TWO TURNS THE SHOTGUN'S MESHES NEED, and for the same reasons: `gltf_split` writes every
-- group with the muzzle at the FILE's +X, and Blender's export plus Roblox's import reverse the
-- model along its own long axis (task 107, measured). Reusing `Gun.MESH_ROTATION_DEG` rather than
-- re-typing 270 means a correction to that measurement reaches both guns.
Geometry.MESH_ROTATION_DEG = Gun.MESH_ROTATION_DEG

Geometry.FOLDER_NAME = "ViewmodelRifle" -- where the server parks this weapon's published meshes
Geometry.BODY_NAME = "RifleBody"
-- THE GROUP THAT MOVES. The shotgun's is `Barrels` and it hinges; this one is `Bolt` and it slides,
-- which is what `CYCLE_KIND` tells `Camera.Viewmodel.hinge` (design 8.2).
Geometry.CYCLE_GROUP_NAME = "Bolt"
Geometry.CYCLE_KIND = "slide"

-- The same four keys the WORLD rifle wears (`Weapons.ROWS.rifle.ASSET_KEYS` -- the SCOPED row):
-- unlike model B, which has a world gun and a viewmodel gun, this rifle is ONE model and both draw
-- it. THE OPEN-SIGHTED ROW WEARS THREE OF THEM (task 143): the viewmodel folder still publishes all
-- four, and `rifle_open` simply never clones `rifle.scope`.
Geometry.ASSET_KEYS = table.freeze({ "rifle.action", "rifle.stock", "rifle.bolt", "rifle.scope" })

Geometry.MESH_KEYS = table.freeze({
	Stock = "rifle.stock",
	Action = "rifle.action",
	Bolt = "rifle.bolt",
	Scope = "rifle.scope",
})

-- The scope's own axis, measured: the tube's centre line is 0.297 above the Handle's origin, which
-- is 0.177 above the bore -- a scope sits high over a bolt action, and the aim pose is solved from
-- it rather than from a number somebody liked (`Mode.aimOffset`).
local SCOPE_AXIS_Y = 0.2972
-- THE DRAWN MAGAZINE, SIZED OFF THE WOOD IT SITS UNDER (task 143). Task 142's was a brick: 0.21
-- studs deep, hung from the ACTION box's underside, which on this model is -0.2058 -- a quarter of a
-- stud below the stock line, so it read as a block bolted on rather than a box magazine.
--
-- MEASURED on the Rigby's own `Wood_Low` node, in the Handle's frame, over the two slices that cover
-- the magazine well: at z +0.35..+0.55 the stock's underside is -0.0659 and at +0.55..+0.75 it is
-- -0.0786. A real bolt-action box sits NEARLY FLUSH -- a few hundredths proud of that line -- so the
-- box is 0.11 deep and its floor lands at -0.145, which is 0.072 below the wood instead of 0.28.

-- THE BEAD IS DRAWN, BECAUSE THE MODEL HAS A BAND AND NO BEAD ON IT (task 143). Karen asked for a
-- rifle *"where aiming true nozzle"* -- down the barrel to a front sight -- and the Rigby's twelve
-- nodes carry no sight NODE at all: `Circle_Low` is a 138-triangle swivel on the LEFT FLANK of the
-- action (x -0.095..-0.078, z +0.11..+0.18) and `Safety_Low` is the safety on top at z +0.77. It is
-- a scope-only rifle as it ships. What it DOES have is inside `Barrel_Low` itself, and round 1 of
-- this task missed it: a small tube on top of the barrel at the muzzle -- the band of a banded front
-- sight, measured below. So the bead is a drawn ball ON that band, exactly as the shotgun's is
-- (`Gun.pieces`'s `Bead`), and for the same reason: there is nothing in the file to upload.
--
-- MEASURED AT THE MUZZLE, NOT OVER THE WHOLE NODE (the Reviewer's round-1 note: a tapered barrel
-- would put a bead placed from the node's maximum proud of the muzzle's own top line). The barrel IS
-- tapered and its axis also rises toward the receiver -- `driven-hunt-runs/t143-muzzle.py` slices
-- `Barrel_Low`'s 598 vertices and `t143-muzzle3.py` fits the rings:
--
--   the barrel's own tube at the muzzle   centre (-0.0138, +0.0920)  r 0.0364  -> its top is +0.1284
--   the barrel further back, z -1.0..-0.7 centre (-0.0141, +0.1162)  r 0.0364
--   A SECOND, SMALLER TUBE ON TOP OF IT   centre (-0.0150, +0.1634)  r 0.0202, z -2.200..-2.095
--
-- So the model is NOT bare at the muzzle after all: it carries a 0.040-stud (10 mm) tube, 0.105
-- studs (26 mm) long, ending flush with the muzzle -- the BAND of a banded front sight, with no
-- bead and no blade on it. +0.1844 is the top of THAT, at the bead's own z, and it is also where the
-- node's maximum comes from. The bead is drawn sitting on the band, which is where a bead belongs.
--
-- IT IS DRAWN ON THE HANDLE'S CENTRE LINE (x = 0) rather than on the band's x = -0.015, because the
-- bullet leaves at x = 0 (`Rifle.CONFIG.MUZZLE_OFFSET`) and a sight that disagrees with the bore is
-- a sight that lies. The 3.5 mm is the MESH sitting off-centre in the Handle, not an aiming error.
local BEAD_DIAMETER = 0.055
local SIGHT_BAND_TOP_Y = 0.1844 -- the band's top at the bead's own z, NOT the barrel's
local STOCK_UNDERSIDE_AT_WELL = -0.0725 -- the mean of the two measured slices
local MAGAZINE_DROP = 0.11 -- how deep the box is, not how far it hangs
local MAGAZINE_PROUD = 0.072 -- how far its floor sits below the wood
local SCOPE_OCULAR_Z = 0.9291 -- the rear lens: what the eye looks into
local SCOPE_OBJECTIVE_Z = -0.2081 -- the front lens

-- The bolt turns about its own body's centre line, which is a hair below the bore.
local BOLT_AXIS_Y = 0.11

local STEEL_MATERIAL = Enum.Material.SmoothPlastic -- `Metal` mirrors the sky; see `Gun`'s own note

local function span(low: number, high: number): (number, number)
	return high - low, (high + low) / 2
end

-- Every measurement this gun has, scaled by the Handle's length so that a different `HANDLE_SIZE.Z`
-- moves the whole gun together. 4.4 is what the meshes were baked at, so at 4.4 the numbers below
-- are exactly the measured ones.
function Geometry.layout(config)
	local total = (config and config.HANDLE_SIZE or Rifle.CONFIG.HANDLE_SIZE).Z
	local k = total / 4.4
	local stockW, stockX = span(-0.1145 * k, 0.0975 * k)
	local stockH, stockY = span(-0.5156 * k, 0.1262 * k)
	local stockL, stockZ = span(-0.8483 * k, 2.2 * k)
	local actionW, actionX = span(-0.0945 * k, 0.0668 * k)
	local actionH, actionY = span(-0.2058 * k, 0.337 * k)
	local actionL, actionZ = span(-2.2 * k, 0.9092 * k)
	local boltW, boltX = span(-0.064 * k, 0.115 * k)
	local boltH, boltY = span(0.0167 * k, 0.1887 * k)
	local boltL, boltZ = span(0.2034 * k, 0.8258 * k)
	local scopeW, scopeX = span(-0.0919 * k, 0.0864 * k)
	local scopeH, scopeY = span(0.2003 * k, 0.3941 * k)
	local scopeL, scopeZ = span(-0.2081 * k, 0.9291 * k)
	return table.freeze({
		total = total,
		half = total / 2,
		muzzleZ = -total / 2,
		meshCentreY = MESH_CENTRE_Y * k,
		scopeAxisY = SCOPE_AXIS_Y * k,
		scopeOcularZ = SCOPE_OCULAR_Z * k,
		scopeObjectiveZ = SCOPE_OBJECTIVE_Z * k,
		boltAxisY = BOLT_AXIS_Y * k,
		stock = { size = Vector3.new(stockW, stockH, stockL), at = Vector3.new(stockX, stockY, stockZ) },
		action = { size = Vector3.new(actionW, actionH, actionL), at = Vector3.new(actionX, actionY, actionZ) },
		bolt = { size = Vector3.new(boltW, boltH, boltL), at = Vector3.new(boltX, boltY, boltZ) },
		scope = { size = Vector3.new(scopeW, scopeH, scopeL), at = Vector3.new(scopeX, scopeY, scopeZ) },
		-- The drawn front sight, on the barrel's measured top line (task 143).
		beadY = SIGHT_BAND_TOP_Y * k,
		beadDiameter = BEAD_DIAMETER * k,
		-- THE MAGAZINE IS DRAWN, BECAUSE THE MODEL HAS NONE (task 142). The Rigby's four groups are
		-- stock, action, bolt and scope -- there is no detachable box in the file to upload, so this
		-- is a part, exactly as the shotgun's bore discs are. It hangs under the ACTION's own
		-- stock line (see the constants above), is a little narrower than the action and short, and
		-- sticks out far enough to be something a hand can be seen taking hold of.
		magazine = {
			size = Vector3.new(actionW * 0.74, MAGAZINE_DROP * k, 0.42 * k),
			-- UNDER THE RECEIVER, NOT UNDER THE BARREL, and that distinction was measured on screen:
			-- the `action` GROUP spans -2.2 to +0.909 because it holds the barrel as well, so its
			-- centre is a stud and a half out along the bore -- a magazine placed from it hangs in
			-- mid-air beside the fore-end, which is exactly what task 142's first frame showed. The
			-- BOLT's box is over the receiver (that is what a bolt sits in), so the magazine is placed
			-- from that, a little forward of the bolt's own centre where the well is.
			--
			-- ...AND ITS FLOOR IS SET FROM THE WOOD, not from the action box (task 143): see
			-- `STOCK_UNDERSIDE_AT_WELL`. The centre is half the box above its own floor, which puts
			-- the floor 0.072 studs under the stock line instead of 0.28.
			at = Vector3.new(
				actionX,
				(STOCK_UNDERSIDE_AT_WELL - MAGAZINE_PROUD + MAGAZINE_DROP / 2) * k,
				boltZ - 0.17 * k
			),
		},
	})
end

-- WHICH SIGHT THIS ROW CARRIES (task 143). `"bead"` is the open-sighted rifle; anything else --
-- including a row written before this task -- is the scope. One gun, one geometry module, and the
-- ROW decides, exactly as `CYCLE_EJECTS` decides what the bolt throws.
function Geometry.sightKind(config): string
	return (config and config.SIGHT) or "scope"
end

-- WHERE THE BEAD SITS, AND THE ONE PLACE THAT DECIDES IT -- the Reviewer's round-1 note, and the rule
-- the shotgun already keeps: `Gun.beadOffset` is read by `Gun.sight` AND by the drawn `Bead` piece,
-- so the point the eye is laid on and the thing the eye sees cannot drift apart. Two copies of this
-- expression would drift silently, because nothing in the game compares them.
function Geometry.beadOffset(config): Vector3
	local at = Geometry.layout(config)
	return Vector3.new(0, at.beadY, at.muzzleZ + at.beadDiameter)
end

-- WHERE THE EYE LOOKS, and that is the whole difference between the two rifles.
--
-- FOR THE SCOPE it is the OCULAR lens rather than a bead: the aim pose puts this point
-- `EYE_RELIEF_STUDS` in front of the eye on the camera's axis (`Mode.aimOffset`), so the tube then
-- runs away from the eye down the view axis and the scope picture is centred BECAUSE OF WHERE THE
-- SCOPE IS.
--
-- FOR OPEN SIGHTS it is the BEAD at the muzzle, on the barrel's top line -- so the same machinery
-- lays the eye along the barrel to the front sight, which is Karen's *"aiming true nozzle"* and is
-- bit-for-bit how the shotgun's bead already works (`Gun.sight`). Nothing here is tuned by eye.
function Geometry.sight(config): CFrame
	local at = Geometry.layout(config)
	if Geometry.sightKind(config) == "bead" then
		-- Identity rotation: (0, 0, -1) is already the muzzle direction in this frame and the bead is
		-- on the gun's centre line, so the sight looks exactly where the barrel points.
		return CFrame.new(Geometry.beadOffset(config))
	end
	return CFrame.new(0, at.scopeAxisY, at.scopeOcularZ)
end

function Geometry.muzzle(config): CFrame
	local at = Geometry.layout(config)
	return CFrame.new(0, 0.12 * (at.total / 4.4), at.muzzleZ)
end

-- The line the bolt turns about: along the gun, through the bolt body's own centre.
function Geometry.boltAxis(config): Vector3
	local at = Geometry.layout(config)
	return Vector3.new(0, at.boltAxisY, 0)
end

-- A break-action's hinge, which this gun does not have. It answers the bolt's axis so that a caller
-- written for the shotgun gets a point on the gun rather than nil.
function Geometry.hinge(config): Vector3
	return Geometry.boltAxis(config)
end

-- Every piece of the first-person rifle, in build order. Pure.
--
-- FOUR MESHES AND NO LENS. The drawn lens is GONE (task 142) and that is Karen's own finding:
-- *"in front of scope when not aiming has circle transperent it shouldn't be like that"*. It was a
-- faceted translucent cylinder on the objective, and from the carry pose it read as a pale grey plug
-- stuck on the end of the tube -- task 141's own frame description had already called it that and
-- done nothing. The scope MESH has its own objective end and needs no help; the disc only ever
-- existed for the build where the mesh had not loaded, which task 141 made rare and task 142 makes
-- somebody else's problem. Archived with its numbers in
-- `backups/2026-10-10-rifle-drawn-lens.md`.
function Geometry.pieces(config): { Piece }
	local at = Geometry.layout(config)
	local meshAt = CFrame.new(0, at.meshCentreY, 0) * CFrame.Angles(0, math.rad(Geometry.MESH_ROTATION_DEG), 0)
	local look = (config and config.LOOK) or Rifle.CONFIG.LOOK
	local sight = Geometry.sightKind(config)
	-- ONE LIST, FILTERED BY THE ROW'S SIGHT (task 143). `skipFor` drops a piece for that sight and
	-- `onlyFor` keeps one just for it, so the two rifles are the SAME gun with the glass on or off
	-- rather than two piece lists that drift apart.
	local function wanted(piece): boolean
		if piece.skipFor ~= nil and piece.skipFor == sight then
			return false
		end
		if piece.onlyFor ~= nil and piece.onlyFor ~= sight then
			return false
		end
		return true
	end
	local kept = {}
	for _, piece in ipairs({
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
			-- THE MAGAZINE (task 142). Karen: *"in magazine 3 shells then it changes with left hand
			-- magazine"*. Dark blued steel, square, under the action where a box magazine lives, and
			-- its own piece rather than part of the body group so `Viewmodel.magazine` can drop it
			-- out of the gun and put a fresh one in without touching anything else.
			name = "Magazine",
			group = "body" :: Gun.Group,
			size = at.magazine.size,
			offset = CFrame.new(at.magazine.at),
			color = look.magazine or look.barrel,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Block,
			reflectance = 0.04,
		},
		{
			name = Geometry.CYCLE_GROUP_NAME,
			group = "barrels" :: Gun.Group, -- the group that MOVES; `Gun.Group`'s second value
			meshKey = Geometry.MESH_KEYS.Bolt,
			meshOffset = meshAt,
			size = at.bolt.size,
			offset = CFrame.new(at.bolt.at),
			color = look.barrel,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
		},
		{
			name = "Scope",
			-- `skipFor` IS READ BY `Geometry.pieces` BELOW (task 143): the open-sighted rifle wears
			-- the same four groups minus this one. The scope's RINGS stay, because they are part of
			-- the `action` group's own mesh (`Vijsjes_Low`, the screws) and not a piece of their own
			-- -- and a rifle with its mounts still on is what a hunter who took the glass off has.
			skipFor = "bead",
			group = "body" :: Gun.Group,
			meshKey = Geometry.MESH_KEYS.Scope,
			meshOffset = meshAt,
			size = at.scope.size,
			offset = CFrame.new(at.scope.at),
			color = look.scope,
			material = STEEL_MATERIAL,
			shape = Enum.PartType.Block,
			-- A GHOST, NOT A WALL, AND THE SECOND SCOPED FRAME IS WHY (task 140, rule 5). Every
			-- other fallback box in this game sits BESIDE the sight line; this one sits ON it -- the
			-- eye looks straight down the tube's own axis -- so drawn solid it is a grey slab across
			-- the whole sight picture for however long the upload takes to arrive. The real scope is
			-- a hollow mesh and you see the world through it; until it lands you see a ghost of one
			-- and can still aim.
			transparency = 0.75,
		},
		{
			-- THE FRONT SIGHT, DRAWN (task 143): see `BEAD_DIAMETER` above for why it is drawn and
			-- where its height came from. `onlyFor` is the mirror of `skipFor`.
			name = "Bead",
			onlyFor = "bead",
			group = "body" :: Gun.Group,
			size = Vector3.new(at.beadDiameter, at.beadDiameter, at.beadDiameter),
			-- `Geometry.beadOffset`, the same expression `Geometry.sight` aims with. Not a copy of it.
			offset = CFrame.new(Geometry.beadOffset(config)),
			color = look.bead or Color3.fromRGB(214, 176, 96),
			material = Enum.Material.Metal,
			shape = Enum.PartType.Ball,
			reflectance = 0.25,
		},
	}) do
		if wanted(piece) then
			table.insert(kept, piece)
		end
	end
	return kept
end

function Geometry.partCount(config): number
	return #Geometry.pieces(config) + 2
end

return Geometry
