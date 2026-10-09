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

-- The same four keys the WORLD rifle wears (`Weapons.ROWS.rifle.ASSET_KEYS`): unlike model B, which
-- has a world gun and a viewmodel gun, this rifle is ONE model and both draw it.
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
	})
end

-- WHERE THE EYE LOOKS, and for a scoped rifle that is the OCULAR lens rather than a bead: the aim
-- pose puts this point `EYE_RELIEF_STUDS` in front of the eye on the camera's axis
-- (`Mode.aimOffset`), so the tube then runs away from the eye down the view axis and the scope
-- picture is centred BECAUSE OF WHERE THE SCOPE IS. Nothing here is tuned by eye.
function Geometry.sight(config): CFrame
	local at = Geometry.layout(config)
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
	return {
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
	}
end

function Geometry.partCount(config): number
	return #Geometry.pieces(config) + 2
end

return Geometry
