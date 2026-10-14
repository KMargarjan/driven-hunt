--!strict
-- Lobby.Build: THE ONE WRITER OF EVERY PART IN `Workspace.Lobby` -- the lodge and its warm inside, the
-- trophy heads on its wall, the four parked trucks, the road and its fences, the tree line at the
-- field's edge, the marked circle, its sign and the lodge spawn.
--
-- KAREN chose the house herself: a **"Wooden log lodge"** -- logs, a porch, antlers over the door,
-- warm inside -- and *"Walk to a car"* for starting a hunt. The SHOP inside is task 178: this builds
-- the empty counter and a placeholder sign and nothing more.
--
-- SINCE TASK 180 IT IS TWO BUILDS, AND WHICH ONE RAN IS A COUNTED FACT. Karen, 2026-10-14: *"we need
-- better house we can use free models / we need car truck model or hunting bus also use free model"*.
-- So the LODGE, the four TRUCKS, the two kinds of TROPHY HEAD and the TREE LINE are clones of
-- script-free free Creator Store models parked in `Workspace.LobbyAssets` (Studio content, which Rojo
-- does not manage and Connect does not delete), and task 177's PARTS BUILD is what happens when a
-- template is not there -- per piece, so a missing truck does not cost you the lodge.
--
-- WHY A CLONE AND NOT AN ASSET ID, so it is not re-litigated (research note sections 2 and 6):
-- `InsertService:LoadAsset` refuses a free Creator Store model whose creator did not tick share
-- (task 152 measured it: *"User is not authorized to access Asset."*), the documented escape
-- `AssetService.AllowInsertFreeAssets` is `RobloxScriptSecurity` on read AND write, a `.model.json`
-- cannot carry geometry (the harness fails a typed `{"Vector3": ...}` as "cannot compare"), and
-- `.rbxm` is banned. StudioMCP's `insert_asset` puts the model in the place with no human click, and
-- the one thing left to write is the clone.
--
-- Every number it uses is in `Lobby.CONFIG`, so moving the lodge, changing a model or adding a fifth
-- truck bay changes that table and not this module.
--
-- IT DECIDES NOTHING AND OWNS NO STATE. `container` and the anchor are arguments, so a spec builds
-- the whole lobby into its own Folder and destroys it -- which is what makes the part budget, the
-- collision set and "no Script anywhere in the tree" checkable claims rather than promises.
--
-- THE FOLDER IS PARENTED LAST: one replication step for the whole lobby, `TestArena.build`'s own
-- rule.
--
-- `CanQuery = false` ON EVERY COSMETIC PART IS LOAD-BEARING and not tidiness -- the rule
-- `ForestTest.Markers` states and the outfit's plates follow: *a slab that stops a pellet changes
-- what the shot hit*. The only parts that collide are the ones a player stands on or cannot walk
-- through: the floor, the walls, the roof and the porch.
--
--   Enum.Material    https://create.roblox.com/docs/reference/engine/enums/Material
--   SpawnLocation    https://create.roblox.com/docs/reference/engine/classes/SpawnLocation
--   SurfaceGui       https://create.roblox.com/docs/reference/engine/classes/SurfaceGui
--
-- Design: docs/design/lobby.md (sections 9, 9.2, 12.2, 16.1 case 7)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 4),
--         docs/research/2026-10-14-lobby-free-models.md (the free models, task 180)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))

local Build = {}

-- WHAT THE LAST BUILD MADE. The module never prints: a tool that `require`s it over StudioMCP gets a
-- sandboxed copy with empty state (measured, task 122), so the owner prints and this answers.
-- `models` is how many free-model templates were cloned, `fallbacks` how many were asked for and not
-- found (task 180), and `strippedScripts` how many script instances a template carried in -- all
-- three so "which build ran" is a number the spec and the boot's own log line can read, never a
-- belief.
local stats = { parts = 0, solids = 0, builds = 0, models = 0, fallbacks = 0, strippedScripts = 0 }

function Build.stats()
	return table.clone(stats)
end

-- ONE PART. `solid` is the whole of the collision decision: true for the shell a player stands on
-- and walks through the door of, false -- and then also unqueryable, untouchable and shadowless --
-- for everything cosmetic.
local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	solid: boolean,
	parent: Instance
): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.CFrame = cframe
	made.Anchored = true
	made.Color = color
	made.Material = material
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.CanCollide = solid
	if not solid then
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
	end
	made.Parent = parent
	stats.parts += 1
	if solid then
		stats.solids += 1
	end
	return made
end

-- A LOG: a cylinder lying along one horizontal axis. `axis` is "x" or "z", which is the only
-- freedom a log wall needs, so there is no rotation to get wrong.
local function log(name: string, length: number, centre: Vector3, axis: string, cfg, parent: Instance): Part
	local d = cfg.LODGE.LOG_DIAMETER
	local made = part(
		name,
		Vector3.new(length, d, d),
		CFrame.new(centre) * (if axis == "z" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity),
		cfg.LODGE.LOG_COLOR,
		cfg.LODGE.MATERIAL,
		true,
		parent
	)
	made.Shape = Enum.PartType.Cylinder
	return made
end

local function post(
	name: string,
	diameter: number,
	height: number,
	centre: Vector3,
	color: Color3,
	parent: Instance
): Part
	local made =
		part(name, Vector3.new(diameter, height, diameter), CFrame.new(centre), color, Enum.Material.Wood, true, parent)
	made.Shape = Enum.PartType.Cylinder
	-- A cylinder's own length is its X, so a standing post is the lying one turned a quarter turn --
	-- the same correction `Horn.pieces` and `Markers.ring` make.
	made.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2)
	return made
end

-- A BOARD WITH WORDS ON IT. A `SurfaceGui` is not script-like, so the harness's "no script outside
-- Rojo-managed paths" check is unaffected -- and it is the only way to put a sentence on a plank
-- without an uploaded texture. The board is cosmetic, so it does not collide and cannot stop a shot.
local function sign(name: string, size: Vector3, cframe: CFrame, text: string, parent: Instance): Part
	local board = part(name, size, cframe, Color3.fromRGB(58, 44, 32), Enum.Material.WoodPlanks, false, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.AlwaysOnTop = false
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(246, 226, 190)
	label.Text = text
	label.Parent = gui
	return board
end

-- ---------------------------------------------------------- the free models (task 180)

-- THE ONE PLACE A STUDIO-MADE TEMPLATE BECOMES A LOBBY INSTANCE, and the reason it is a CLONE of
-- something already in the world rather than an `InsertService:LoadAsset` of an id is measured and
-- written down in `Lobby.TEMPLATES_NAME`'s comment and in the research note (section 3).
--
-- `templates` IS AN ARGUMENT, exactly like `container` and for the same reason: a spec hands it a
-- Folder it built itself, or nil, and both branches -- the free-model lodge and task 177's parts
-- lodge -- are reachable without a Creator Store round trip. Nothing in here reads `Workspace`.
--
-- A MISSING TEMPLATE IS NOT AN ERROR. It answers nil, the caller builds the parts version, and
-- `stats.models` / `stats.fallbacks` say which happened -- so "the lobby still builds when a model
-- is gone" is a counted fact and not a promise.
--
-- IT STRIPS SCRIPTS ON THE WAY THROUGH, and that is belt AND braces: the four chosen models carry no
-- script at all (measured, task 180), and a free model is the classic place to hide one. CLAUDE.md:
-- *"Nothing script-like (Script, LocalScript, ModuleScript) is ever created in Studio."*
local function scriptsIn(instance: Instance): number
	local found = 0
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
			found += 1
		end
	end
	return found
end

-- WHERE A CLONE'S BOTTOM IS. A Model's pivot is its bounding-box centre unless somebody set a
-- PrimaryPart, so "stand it on the shelf" is measured after the rotation is applied and never
-- guessed from the size the Creator Store listed.
local function sitOnShelf(model: Model, shelfY: number)
	local box, size = model:GetBoundingBox()
	local lowest = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, shelfY - lowest, 0))
end

local function clone(
	templates: Instance?,
	key: string,
	name: string,
	scale: number,
	at: Vector3,
	yaw: number,
	parent: Instance,
	cosmetic: boolean
): Instance?
	if templates == nil then
		return nil
	end
	local template = (templates :: Instance):FindFirstChild(key)
	if template == nil then
		stats.fallbacks += 1
		return nil
	end
	local made = template:Clone()
	made.Name = name
	stats.strippedScripts += scriptsIn(made)
	if made:IsA("Model") then
		if scale ~= 1 then
			made:ScaleTo(scale)
		end
		made:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0))
		sitOnShelf(made :: Model, at.Y)
	elseif made:IsA("BasePart") then
		made.CFrame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	end
	for _, descendant in ipairs(made:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- ANCHORED ALWAYS: a free model ships with whatever the builder left, and one unanchored
			-- plank in a lodge is a lodge that falls over on the first Play.
			descendant.Anchored = true
			if cosmetic then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
			stats.parts += 1
			if descendant.CanCollide then
				stats.solids += 1
			end
		end
	end
	if made:IsA("BasePart") then
		made.Anchored = true
		if cosmetic then
			made.CanCollide = false
			made.CanQuery = false
			made.CanTouch = false
		end
		stats.parts += 1
		if made.CanCollide then
			stats.solids += 1
		end
	end
	made.Parent = parent
	stats.models += 1
	return made
end

-- ---------------------------------------------------------------- the lodge

-- THE ROOM INSIDE THE LODGE, whichever lodge got built. Everything that hangs on a wall or stands on
-- the floor is placed against THIS and never against `cfg.LODGE.SIZE`, because the free model's room
-- (19.8 x 19.8 x 7.4) and task 177's (38 x 26 x 9) are different rectangles and a constant offset
-- can only be right for one of them.
export type Room = { centre: Vector3, halfX: number, halfZ: number, height: number }

-- THE TROPHY HEADS ON THE WALL. Karen, 2026-10-14: *"and then on walls we can make trophys like head
-- of deer head of boar"*.
--
-- A MOUNT NAMES A WALL, so the three rows in `CONFIG.TROPHIES.MOUNTS` hang correctly in either room.
-- Each head gets a plank behind it: the deer model carries its own shield and the boar model does
-- not, and one plank for both is cheaper than two code paths and reads as a matched set.
local function trophies(inside: Instance, room: Room, cfg, templates: Instance?)
	local folder = Instance.new("Folder")
	folder.Name = "Trophies"
	folder.Parent = inside
	local spec = cfg.TROPHIES
	for index, mount in ipairs(spec.MOUNTS) do
		-- WHICH WALL, AS THE ONE PLACE THE FOUR NAMES TURN INTO GEOMETRY. `yaw` faces the head INTO
		-- the room, so a head on the north wall looks south.
		local at, yaw
		if mount.wall == "north" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z + room.halfZ), math.pi
		elseif mount.wall == "south" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z - room.halfZ), 0
		elseif mount.wall == "west" then
			at, yaw = Vector3.new(room.centre.X - room.halfX, 0, room.centre.Z + mount.along), math.pi / 2
		else
			at, yaw = Vector3.new(room.centre.X + room.halfX, 0, room.centre.Z + mount.along), -math.pi / 2
		end
		local y = room.centre.Y + math.min(spec.HEIGHT_STUDS, room.height - 2)
		local facing = CFrame.new(Vector3.new(at.X, y, at.Z)) * CFrame.Angles(0, yaw, 0)
		part(
			string.format("Plaque%d", index),
			spec.PLAQUE,
			facing * CFrame.new(0, 0, -spec.PLAQUE.Z / 2),
			spec.PLAQUE_COLOR,
			Enum.Material.WoodPlanks,
			false,
			folder
		)
		local key = if mount.kind == "boar" then Data.TEMPLATE.BOAR else Data.TEMPLATE.DEER
		local head = clone(
			templates,
			key,
			string.format("%s%d", if mount.kind == "boar" then "BoarHead" else "DeerHead", index),
			1,
			(facing * CFrame.new(0, 0, -spec.PLAQUE.Z - spec.CLEAR_STUDS)).Position,
			yaw,
			folder,
			true
		)
		if head == nil then
			-- NO MODEL, STILL A TROPHY: a pair of cylinders on the plank, which is what task 177's
			-- antlers over the door already are. The lobby never comes up empty-walled.
			for _, side in ipairs({ -1, 1 }) do
				local spur = part(
					string.format("Tine%d%s", index, if side < 0 then "W" else "E"),
					Vector3.new(0.35, 2.4, 0.35),
					facing * CFrame.new(side * 0.8, 0.9, -spec.PLAQUE.Z - 0.4) * CFrame.Angles(0, 0, side * 0.5),
					Color3.fromRGB(226, 216, 192),
					Enum.Material.SmoothPlastic,
					false,
					folder
				)
				spur.Shape = Enum.PartType.Cylinder
			end
		end
	end
end

-- ONE WALL OF LOGS, with an optional DOORWAY GAP. Karen asked for a *"door you walk through"*, so
-- the door is the absence of parts and never a door panel: the courses below the lintel are built as
-- two segments, one each side of the gap, and the course above it spans the whole wall.
local function logWall(
	folder: Instance,
	name: string,
	axis: string,
	length: number,
	along: number, -- the wall's centre on its own axis
	across: number, -- the wall's position on the other axis
	baseY: number,
	cfg,
	doorWidth: number?,
	doorHeight: number?
): number
	local d = cfg.LODGE.LOG_DIAMETER
	local courses = math.max(1, math.floor(cfg.LODGE.SIZE.Y / d))
	local placed = 0
	for course = 1, courses do
		local y = baseY + d / 2 + (course - 1) * d
		local gap = doorWidth or 0
		local lintelAt = baseY + (doorHeight or 0)
		local function at(a: number, c: number): Vector3
			return if axis == "x" then Vector3.new(a, y, c) else Vector3.new(c, y, a)
		end
		if gap > 0 and y < lintelAt then
			local side = (length - gap) / 2
			if side > 0 then
				log(string.format("%s%dW", name, course), side, at(along - (gap + side) / 2, across), axis, cfg, folder)
				log(string.format("%s%dE", name, course), side, at(along + (gap + side) / 2, across), axis, cfg, folder)
				placed += 2
			end
		else
			log(string.format("%s%d", name, course), length, at(along, across), axis, cfg, folder)
			placed += 1
		end
	end
	return placed
end

-- THE GABLE AND THE ROOF of one lodge. Two sloped slabs meeting at the ridge, and one wedge per end
-- so the triangle above the walls is filled rather than open to the sky.
local function roof(folder: Instance, origin: Vector3, cfg)
	local size = cfg.LODGE.SIZE
	local wallTop = origin.Y + size.Y
	local ridge = origin.Y + cfg.LODGE.RIDGE_STUDS
	local rise = ridge - wallTop
	local halfDepth = size.Z / 2
	local slope = math.sqrt(rise * rise + halfDepth * halfDepth)
	local pitch = math.atan2(rise, halfDepth)
	local overhang = 4
	for _, side in ipairs({ -1, 1 }) do
		local midZ = origin.Z + side * halfDepth / 2
		local midY = (wallTop + ridge) / 2
		local slab = part(
			if side < 0 then "RoofSouth" else "RoofNorth",
			Vector3.new(size.X + overhang, 1, slope + overhang / 2),
			CFrame.new(origin.X, midY, midZ) * CFrame.Angles(side * pitch, 0, 0),
			cfg.LODGE.ROOF_COLOR,
			cfg.LODGE.ROOF_MATERIAL,
			true,
			folder
		)
		slab.Name = slab.Name
	end
	-- The two gable triangles, as wedges: a WedgePart's slope runs along its own +Z, so one is turned
	-- to face the other.
	for _, side in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local wedge = Instance.new("WedgePart")
			wedge.Name = string.format("Gable%s%s", if side < 0 then "S" else "N", if half < 0 then "W" else "E")
			wedge.Size = Vector3.new(0.8, rise, halfDepth)
			wedge.Anchored = true
			wedge.Color = cfg.LODGE.LOG_COLOR
			wedge.Material = cfg.LODGE.MATERIAL
			wedge.CanCollide = true
			wedge.CFrame = CFrame.new(
				origin.X + half * (size.X / 2 - 0.4),
				wallTop + rise / 2,
				origin.Z + side * halfDepth / 2
			) * CFrame.Angles(0, if side < 0 then math.pi else 0, 0)
			wedge.Parent = folder
			stats.parts += 1
			stats.solids += 1
		end
	end
end

-- THE WARM INSIDE: a stone fireplace with ONE `PointLight`, a table, two benches, and task 178's
-- empty shop counter with its placeholder sign. Nothing here is animated and nothing is written per
-- frame -- a fire that flickers is a second writer of a light, for a lobby nobody is fighting in.
local function interior(folder: Instance, room: Room, cfg, templates: Instance?)
	local origin = room.centre
	local inside = Instance.new("Folder")
	inside.Name = "Inside"
	inside.Parent = folder

	local backZ = origin.Z + room.halfZ - 2
	-- THE CHIMNEY STOPS AT THE CEILING. The free model's room is 7.4 studs high against task 177's
	-- 9, so a 13-stud stack written as a constant would have pushed a slate column through the roof
	-- of the lodge Karen is being shown -- the "measured correct, looked wrong" failure this project
	-- is built around (`docs/PROJECT_CONTEXT.md`).
	local stackHeight = math.min(13, room.height - 0.4)
	local stack = part(
		"Fireplace",
		Vector3.new(9, stackHeight, 3),
		CFrame.new(origin.X - room.halfX / 2, origin.Y + stackHeight / 2, backZ),
		Color3.fromRGB(104, 104, 104),
		Enum.Material.Slate,
		true,
		inside
	)
	part(
		"Hearth",
		Vector3.new(9, 1, 4),
		CFrame.new(origin.X - room.halfX / 2, origin.Y + 0.5, backZ - 3),
		Color3.fromRGB(88, 88, 88),
		Enum.Material.Slate,
		false,
		inside
	)
	local fire = part(
		"Fire",
		Vector3.new(5, 2.5, 2),
		CFrame.new(origin.X - room.halfX / 2, origin.Y + 1.8, backZ - 2),
		Color3.fromRGB(255, 142, 48),
		Enum.Material.Neon,
		false,
		inside
	)
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Brightness = cfg.LODGE.FIRE_LIGHT.brightness
	light.Range = cfg.LODGE.FIRE_LIGHT.rangeStuds
	light.Color = cfg.LODGE.FIRE_LIGHT.color
	light.Shadows = false
	light.Parent = fire
	stack.Name = stack.Name

	-- The table and its benches.
	local tableTop = part(
		"Table",
		Vector3.new(11, 0.6, 5),
		CFrame.new(origin.X + 4, origin.Y + 4, origin.Z),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		false,
		inside
	)
	tableTop.Name = tableTop.Name
	for index, dx in ipairs({ -4.5, 4.5 }) do
		for jndex, dz in ipairs({ -1.8, 1.8 }) do
			post(
				string.format("TableLeg%d%d", index, jndex),
				0.8,
				3.4,
				Vector3.new(origin.X + 4 + dx, origin.Y + 2, origin.Z + dz),
				cfg.LODGE.FLOOR_COLOR,
				inside
			)
		end
	end
	for index, dz in ipairs({ -4, 4 }) do
		part(
			string.format("Bench%d", index),
			Vector3.new(10, 0.5, 2),
			CFrame.new(origin.X + 4, origin.Y + 2.2, origin.Z + dz),
			cfg.LODGE.FLOOR_COLOR,
			Enum.Material.WoodPlanks,
			false,
			inside
		)
	end

	-- THE SHOP (task 177 built it empty, task 178 opened it): the counter is the DOOR, found by name
	-- through `Lobby.counterPart` and measured against by the server's own reach check. Karen:
	-- *"Hunting house where inside can shop things"*.
	local shop = Instance.new("Folder")
	shop.Name = "Shop"
	shop.Parent = inside
	local counterAt = Vector3.new(origin.X + room.halfX / 2, origin.Y + cfg.LODGE.COUNTER.Y / 2, backZ - 1)
	part(
		"Counter",
		cfg.LODGE.COUNTER,
		CFrame.new(counterAt),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		true,
		shop
	)
	sign(
		"ShopSign",
		Vector3.new(10, 2.6, 0.3),
		CFrame.new(counterAt.X, origin.Y + math.min(7, room.height - 1.5), backZ + 0.8),
		cfg.LODGE.SIGN_TEXT,
		shop
	)

	trophies(inside, room, cfg, templates)
end

-- THE LODGE, AND WHICH OF THE TWO GOT BUILT IS DECIDED IN ONE PLACE.
--
-- Karen, 2026-10-14: *"we need better house we can use free models"*. So the FREE MODEL is first
-- choice and task 177's parts lodge is what happens when it is not there -- a missing template, a
-- renamed folder, a place that has never had the models inserted (the DEV place is exactly that).
-- Both branches end the same way, with the same warm inside and the same shop counter hung on the
-- same measured room, so nothing downstream has to ask which one it got.
local function lodge(container: Instance, anchor: Vector3, cfg, templates: Instance?): Instance
	local folder = Instance.new("Folder")
	folder.Name = "Lodge"
	local origin = anchor + cfg.LODGE.OFFSET
	local size = cfg.LODGE.SIZE
	local halfX, halfZ = size.X / 2, size.Z / 2

	local model = cfg.LODGE.MODEL
	local built = clone(templates, Data.TEMPLATE.LODGE, "House", model.SCALE, origin, model.YAW_RADIANS, folder, false)
	if built ~= nil then
		local scale = model.SCALE
		local room: Room = {
			centre = Vector3.new(
				origin.X + model.ROOM.CENTRE.X * scale,
				origin.Y + model.ROOM.CENTRE.Y * scale,
				origin.Z + model.ROOM.CENTRE.Z * scale
			),
			halfX = model.ROOM.HALF.X * scale,
			halfZ = model.ROOM.HALF.Y * scale,
			height = (model.ROOM.CEILING_Y - model.ROOM.CENTRE.Y) * scale,
		}
		interior(folder, room, cfg, templates)
		folder.Parent = container
		return folder
	end

	part(
		"Floor",
		Vector3.new(size.X, 1, size.Z),
		CFrame.new(origin.X, origin.Y + 0.5, origin.Z),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		true,
		folder
	)
	-- THE FRONT WALL FACES SOUTH (-Z), toward the yard, the truck and the player who spawns there.
	logWall(
		folder,
		"WallS",
		"x",
		size.X,
		origin.X,
		origin.Z - halfZ,
		origin.Y + 1,
		cfg,
		cfg.LODGE.DOOR.X,
		cfg.LODGE.DOOR.Y
	)
	logWall(folder, "WallN", "x", size.X, origin.X, origin.Z + halfZ, origin.Y + 1, cfg)
	logWall(folder, "WallW", "z", size.Z, origin.Z, origin.X - halfX, origin.Y + 1, cfg)
	logWall(folder, "WallE", "z", size.Z, origin.Z, origin.X + halfX, origin.Y + 1, cfg)
	roof(folder, Vector3.new(origin.X, origin.Y + 1, origin.Z), cfg)

	-- THE DOORWAY'S OWN FRAME, so the gap reads as a door and not as a hole. Cosmetic: the two posts
	-- stand beside the opening, never in it.
	for index, dx in ipairs({ -cfg.LODGE.DOOR.X / 2 - 0.6, cfg.LODGE.DOOR.X / 2 + 0.6 }) do
		post(
			string.format("DoorPost%d", index),
			1.2,
			cfg.LODGE.DOOR.Y,
			Vector3.new(origin.X + dx, origin.Y + 1 + cfg.LODGE.DOOR.Y / 2, origin.Z - halfZ),
			cfg.LODGE.LOG_COLOR,
			folder
		)
	end

	-- ANTLERS OVER THE DOOR. Karen's own word. A skull plate and two beams, each with its tines.
	local antlers = Instance.new("Folder")
	antlers.Name = "Antlers"
	antlers.Parent = folder
	local plateY = origin.Y + 1 + cfg.LODGE.DOOR.Y + 1.6
	local bone = Color3.fromRGB(226, 216, 192)
	part(
		"SkullPlate",
		Vector3.new(2.6, 2, 0.8),
		CFrame.new(origin.X, plateY, origin.Z - halfZ - 0.6),
		bone,
		Enum.Material.SmoothPlastic,
		false,
		antlers
	)
	for _, side in ipairs({ -1, 1 }) do
		local beam = part(
			if side < 0 then "BeamW" else "BeamE",
			Vector3.new(0.5, 4.4, 0.5),
			CFrame.new(origin.X + side * 1.4, plateY + 1.6, origin.Z - halfZ - 0.6) * CFrame.Angles(0, 0, side * 0.5),
			bone,
			Enum.Material.SmoothPlastic,
			false,
			antlers
		)
		beam.Shape = Enum.PartType.Cylinder
		beam.CFrame = CFrame.new(origin.X + side * 1.4, plateY + 1.8, origin.Z - halfZ - 0.6)
			* CFrame.Angles(0, 0, math.pi / 2 + side * 0.6)
		for tine = 1, cfg.LODGE.ANTLERS.tines do
			local spur = part(
				string.format("Tine%s%d", if side < 0 then "W" else "E", tine),
				Vector3.new(0.4, 2, 0.4),
				CFrame.new(origin.X + side * (2 + tine * 0.7), plateY + 1.4 + tine * 1.1, origin.Z - halfZ - 0.6),
				bone,
				Enum.Material.SmoothPlastic,
				false,
				antlers
			)
			spur.Shape = Enum.PartType.Cylinder
			spur.CFrame = CFrame.new(spur.Position) * CFrame.Angles(0, 0, math.pi / 2 + side * 1.1)
		end
	end

	-- THE WINDOWS: dark glass set into the side walls, so the lodge is not a blind box.
	for index = 1, cfg.LODGE.WINDOWS do
		local side = if index % 2 == 0 then 1 else -1
		local dz = (if index <= 2 then -1 else 1) * halfZ / 2
		part(
			string.format("Window%d", index),
			Vector3.new(0.6, 4, 5),
			CFrame.new(origin.X + side * halfX, origin.Y + 6, origin.Z + dz),
			Color3.fromRGB(38, 44, 48),
			Enum.Material.Glass,
			false,
			folder
		)
	end

	-- THE PORCH. Karen's word, and it is where she arrives.
	local porch = Instance.new("Folder")
	porch.Name = "Porch"
	porch.Parent = folder
	local depth = cfg.LODGE.PORCH_DEPTH
	local deckZ = origin.Z - halfZ - depth / 2
	part(
		"Deck",
		Vector3.new(size.X, 1, depth),
		CFrame.new(origin.X, origin.Y + 0.5, deckZ),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		true,
		porch
	)
	local postX = size.X / 2 - 1.5
	for index = 1, cfg.LODGE.PORCH_POSTS do
		local dx = if index % 2 == 0 then postX else -postX
		local dz = if index <= 2 then -depth / 2 + 1 else depth / 2 - 1
		post(
			string.format("PorchPost%d", index),
			1.4,
			cfg.LODGE.SIZE.Y,
			Vector3.new(origin.X + dx, origin.Y + 1 + cfg.LODGE.SIZE.Y / 2, deckZ + dz),
			cfg.LODGE.LOG_COLOR,
			porch
		)
	end
	part(
		"PorchRoof",
		Vector3.new(size.X + 3, 1, depth + 2),
		CFrame.new(origin.X, origin.Y + 1 + cfg.LODGE.SIZE.Y, deckZ) * CFrame.Angles(-0.12, 0, 0),
		cfg.LODGE.ROOF_COLOR,
		cfg.LODGE.ROOF_MATERIAL,
		true,
		porch
	)

	interior(folder, {
		centre = Vector3.new(origin.X, origin.Y + 1, origin.Z),
		halfX = halfX - 1,
		halfZ = halfZ - 1,
		height = cfg.LODGE.SIZE.Y,
	}, cfg, templates)
	folder.Parent = container
	return folder
end

-- ---------------------------------------------------------------- the truck

-- ONE TRUCK, BUILT OUT OF PARTS. `bayAt` is where it stands, so the four bays are one loop in
-- `trucks` and this function never knows how many there are.
local function truck(container: Instance, at: Vector3, cfg, name: string): Instance
	local folder = Instance.new("Folder")
	folder.Name = name
	local green = cfg.TRUCK.COLOR
	local dark = Color3.fromRGB(26, 28, 26)
	-- IT POINTS SOUTH (-Z), down the track and out of the yard: a truck that is about to leave.
	local bedZ = at.Z + 4
	part("Bed", Vector3.new(7, 3.4, 8), CFrame.new(at.X, at.Y + 4.4, bedZ), green, Enum.Material.Metal, true, folder)
	for index, dx in ipairs({ -3.4, 3.4 }) do
		part(
			string.format("BedSide%d", index),
			Vector3.new(0.4, 2.6, 8),
			CFrame.new(at.X + dx, at.Y + 7.3, bedZ),
			green,
			Enum.Material.Metal,
			false,
			folder
		)
	end
	part(
		"BedTail",
		Vector3.new(7, 2.6, 0.4),
		CFrame.new(at.X, at.Y + 7.3, bedZ + 4),
		green,
		Enum.Material.Metal,
		false,
		folder
	)
	part(
		"Cab",
		Vector3.new(7, 6.5, 6),
		CFrame.new(at.X, at.Y + 5.9, at.Z - 2.4),
		green,
		Enum.Material.Metal,
		true,
		folder
	)
	part(
		"Windscreen",
		Vector3.new(6.2, 3, 0.4),
		CFrame.new(at.X, at.Y + 7.4, at.Z - 5.3),
		Color3.fromRGB(42, 52, 56),
		Enum.Material.Glass,
		false,
		folder
	)
	part(
		"Bonnet",
		Vector3.new(7, 2.8, 4),
		CFrame.new(at.X, at.Y + 4.4, at.Z - 7.4),
		green,
		Enum.Material.Metal,
		true,
		folder
	)
	part(
		"Bumper",
		Vector3.new(7.4, 1.2, 0.8),
		CFrame.new(at.X, at.Y + 2.9, at.Z - 9.6),
		dark,
		Enum.Material.Metal,
		false,
		folder
	)
	for index = 1, cfg.TRUCK.WHEELS do
		local dx = if index % 2 == 0 then 3.6 else -3.6
		local dz = if index <= 2 then -6 else 4
		local wheel = part(
			string.format("Wheel%d", index),
			Vector3.new(2.2, 5, 5),
			CFrame.new(at.X + dx, at.Y + 2.5, at.Z + dz),
			dark,
			Enum.Material.Rubber,
			false,
			folder
		)
		wheel.Shape = Enum.PartType.Cylinder
	end
	folder.Parent = container
	return folder
end

-- FOUR TRUCKS, SIDE BY SIDE (the Director, task 180), one per party, stepping east from task 177's
-- single bay -- so bay 1 is exactly where the one truck used to stand and the circle beside it has
-- not moved. Task 182 puts a queue pad `TRUCK.PAD_BEHIND_STUDS` behind each.
--
-- EACH BAY FALLS BACK ON ITS OWN. If the template is there every bay is a model and if it is not
-- every bay is parts; the loop does not care, which is what makes "a model failed to load" a
-- survivable state rather than a half-built yard.
local function trucks(container: Instance, anchor: Vector3, cfg, templates: Instance?)
	local folder = Instance.new("Folder")
	folder.Name = "Trucks"
	local model = cfg.TRUCK.MODEL
	for index = 1, cfg.TRUCK.COUNT do
		local at = anchor + cfg.TRUCK.OFFSET + Vector3.new((index - 1) * cfg.TRUCK.BAY_GAP_STUDS, 0, 0)
		local name = string.format("Truck%d", index)
		local made = clone(templates, Data.TEMPLATE.TRUCK, name, model.SCALE, at, model.YAW_RADIANS, folder, false)
		if made == nil then
			truck(folder, at, cfg, name)
		end
	end
	folder.Parent = container
	return folder
end

-- ---------------------------------------------------------------- the marked circle

-- THE RING IS `ForestTest.Markers.RING`'S, BORROWED WHOLE, so the lobby's circle and the hunter's
-- stand circle are the same piece of UI language -- twenty neon chords lifted clear of the ground in
-- hunting orange. Two circles drawn two different ways would teach a player two things.
--
-- THE CHORD RATHER THAN THE TANGENT, which is `Markers.ring`'s own rule: consecutive segments share
-- an endpoint exactly, so the ring cannot gap however `SEGMENTS` is changed.
--
-- NO GROUND READER HERE, and that is the difference from the stand's ring: this circle lies on the
-- lobby's own FLAT shelf, whose height is one number. A raycast per segment would be measuring a
-- surface this system built itself.
local function spot(container: Instance, anchor: Vector3, cfg): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Spot"
	local centre = anchor + cfg.SPOT.OFFSET
	local ring = cfg.SPOT.RING
	local radius = cfg.SPOT.RADIUS_STUDS
	local step = 2 * math.pi / ring.SEGMENTS
	local chord = 2 * radius * math.sin(step / 2)
	for index = 1, ring.SEGMENTS do
		local a, b = (index - 1) * step, index * step
		local fromX, fromZ = centre.X + math.cos(a) * radius, centre.Z + math.sin(a) * radius
		local toX, toZ = centre.X + math.cos(b) * radius, centre.Z + math.sin(b) * radius
		local midX, midZ = (fromX + toX) / 2, (fromZ + toZ) / 2
		local seat = Vector3.new(midX, centre.Y + ring.LIFT_STUDS, midZ)
		local along = Vector3.new(toX - fromX, 0, toZ - fromZ)
		local segment = part(
			string.format("Seg%d", index),
			Vector3.new(chord, ring.HEIGHT_STUDS, ring.THICKNESS_STUDS),
			CFrame.lookAt(seat, seat + along.Unit, Vector3.yAxis) * CFrame.Angles(0, math.pi / 2, 0),
			ring.COLOR,
			Enum.Material.Neon,
			false,
			folder
		)
		segment.Transparency = ring.TRANSPARENCY
	end

	-- THE NAMED PART THE CLIENT READS (design section 10.3). Invisible, unqueryable, and the ONE
	-- definition of where the truck spot is: the server builds it, the Hud's chevron reads it, and
	-- nobody computes the position twice.
	local marker = part(
		Data.SPOT_NAME,
		Vector3.new(radius * 2, 0.4, radius * 2),
		CFrame.new(centre),
		ring.COLOR,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	marker.Transparency = 1

	-- THE SIGN, on a post beside the circle.
	post(
		"SignPost",
		1,
		9,
		Vector3.new(centre.X, centre.Y + 4.5, centre.Z - radius - 1),
		Color3.fromRGB(96, 72, 48),
		folder
	)
	sign(
		"SpotSign",
		Vector3.new(11, 3.2, 0.4),
		CFrame.new(centre.X, centre.Y + 9.6, centre.Z - radius - 1),
		cfg.SPOT.SIGN_TEXT,
		folder
	)
	folder.Parent = container
	return marker
end

-- ---------------------------------------------------------- the road, the fences, the trees

-- THE ROAD TO THE LODGE. Karen, 2026-10-14: *"place could be a bit more nicer like road going to
-- that house and around fields and forrests"*.
--
-- IT STOPS AT THE SHELF'S EDGE, and that is the measurement in `CONFIG.ROAD`'s comment rather than a
-- taste: `Field.fill` flattens 220 x 220 and the ground falls away outside it, so a flat strip laid
-- further would float. Cosmetic and flush, like the track it replaces -- nobody takes cover behind a
-- road.
local function road(container: Instance, anchor: Vector3, cfg)
	local folder = Instance.new("Folder")
	folder.Name = "Road"
	local spec = cfg.ROAD
	local length = spec.FROM_Z - spec.TO_Z
	local midZ = (spec.FROM_Z + spec.TO_Z) / 2
	part(
		"Lane",
		Vector3.new(spec.WIDTH_STUDS, 0.4, length),
		CFrame.new(anchor.X + spec.CENTRE_X, anchor.Y, anchor.Z + midZ),
		spec.COLOR,
		spec.MATERIAL,
		false,
		folder
	)
	for index, side in ipairs({ -1, 1 }) do
		part(
			string.format("Verge%d", index),
			Vector3.new(spec.VERGE_STUDS, 0.35, length),
			CFrame.new(
				anchor.X + spec.CENTRE_X + side * (spec.WIDTH_STUDS + spec.VERGE_STUDS) / 2,
				anchor.Y,
				anchor.Z + midZ
			),
			spec.VERGE_COLOR,
			spec.MATERIAL,
			false,
			folder
		)
	end
	-- THE YARD in front of the lodge and across the truck bays, so the parking is not four trucks
	-- standing in a meadow.
	local bays = (cfg.TRUCK.COUNT - 1) * cfg.TRUCK.BAY_GAP_STUDS
	part(
		"Yard",
		Vector3.new(math.abs(cfg.TRUCK.OFFSET.X - spec.CENTRE_X) + bays + 34, 0.4, 44),
		CFrame.new(anchor.X + (spec.CENTRE_X + cfg.TRUCK.OFFSET.X + bays) / 2, anchor.Y, anchor.Z + cfg.TRUCK.OFFSET.Z),
		spec.COLOR,
		spec.MATERIAL,
		false,
		folder
	)
	-- A woodpile: the piece of field dressing that says somebody lives here. Task 177's, kept.
	for index = 1, 6 do
		local pile = part(
			string.format("Log%d", index),
			Vector3.new(7, 1.6, 1.6),
			CFrame.new(
				anchor.X - 30,
				anchor.Y + 0.8 + math.floor((index - 1) / 3) * 1.6,
				anchor.Z + 34 + ((index - 1) % 3) * 1.7
			),
			Color3.fromRGB(118, 92, 62),
			Enum.Material.Wood,
			false,
			folder
		)
		pile.Shape = Enum.PartType.Cylinder
	end
	folder.Parent = container
end

-- THE POST-AND-RAIL FENCE down both sides of the road: Karen's *"around fields"*, as the one piece of
-- furniture that makes an open shelf read as a field rather than as a lawn. Cosmetic -- a player who
-- walks into it walks through it, which is the right answer for scenery in a lobby.
local function fences(container: Instance, anchor: Vector3, cfg)
	local folder = Instance.new("Folder")
	folder.Name = "Fences"
	local spec = cfg.FENCE
	for _, side in ipairs({ -1, 1 }) do
		local x = anchor.X + cfg.ROAD.CENTRE_X + side * spec.OFF_ROAD_STUDS
		local tag = if side < 0 then "W" else "E"
		for index = 1, spec.POSTS_PER_SIDE do
			local z = anchor.Z + spec.FROM_Z + (index - 1) * spec.SPACING_STUDS
			part(
				string.format("Post%s%d", tag, index),
				spec.POST,
				CFrame.new(x, anchor.Y + spec.POST.Y / 2, z),
				spec.COLOR,
				Enum.Material.Wood,
				false,
				folder
			)
			if index < spec.POSTS_PER_SIDE then
				for rail, railY in ipairs(spec.RAIL_Y) do
					part(
						string.format("Rail%s%d_%d", tag, index, rail),
						Vector3.new(spec.RAIL_THICK, spec.RAIL_THICK, spec.SPACING_STUDS),
						CFrame.new(x, anchor.Y + railY, z + spec.SPACING_STUDS / 2),
						spec.COLOR,
						Enum.Material.Wood,
						false,
						folder
					)
				end
			end
		end
	end
	folder.Parent = container
end

-- THE FOREST EDGE, AND IT IS THE FOREST'S OWN TREES (the Director: *"reuse the forest's trees"*).
-- `LobbyAssets.Trees` holds models copied out of `Workspace.OurForest` in Studio, so the ring of wood
-- round the field is the same wood the drive runs in. No folder, no tree line: the field is open and
-- the forest to the north is still really there.
--
-- COSMETIC, AND THAT IS DELIBERATE. `ForestTest.groundAt` excludes `OurForest`, `Foliage` and
-- `Boars` by NAME, so a queryable copy of a spruce standing in `Workspace.Lobby` would be the one
-- tree in this world a ground raycast could hit -- and the ground under the lobby is what every
-- player placement reads. `CanQuery = false` keeps that promise where the name no longer can.
local function treeLine(container: Instance, anchor: Vector3, cfg, templates: Instance?)
	if templates == nil then
		return
	end
	local wood = (templates :: Instance):FindFirstChild(Data.TEMPLATE.TREES)
	if wood == nil then
		stats.fallbacks += 1
		return
	end
	local kinds = wood:GetChildren()
	if #kinds == 0 then
		stats.fallbacks += 1
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TreeLine"
	local spec = cfg.TREELINE
	-- ONE SEED, SO THE WOOD IS THE SAME WOOD EVERY BOOT. A lobby that reshuffles its trees on each
	-- restart is a lobby nobody can photograph twice, and rule 5 is a screenshot somebody compares.
	local rng = Random.new(1804)
	local span = spec.TO_RADIANS - spec.FROM_RADIANS
	for index = 1, spec.COUNT do
		local angle = spec.FROM_RADIANS + span * ((index - 0.5) / spec.COUNT)
		local radius = spec.RADIUS_STUDS + rng:NextNumber(-spec.JITTER_STUDS, spec.JITTER_STUDS)
		local at = Vector3.new(anchor.X + math.sin(angle) * radius, anchor.Y, anchor.Z + math.cos(angle) * radius)
		local kind = kinds[rng:NextInteger(1, #kinds)]
		local made = kind:Clone()
		made.Name = string.format("Tree%02d", index)
		stats.strippedScripts += scriptsIn(made)
		if made:IsA("Model") then
			made:ScaleTo(rng:NextNumber(spec.SCALE[1], spec.SCALE[2]))
			made:PivotTo(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			sitOnShelf(made :: Model, anchor.Y)
		end
		for _, descendant in ipairs(made:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				stats.parts += 1
			end
		end
		made.Parent = folder
		stats.models += 1
	end
	folder.Parent = container
end

-- ---------------------------------------------------------------- the whole lobby

-- EVERY PART, BUILT ONCE, INTO ITS OWN FOLDER. `container` is an argument, so a spec builds the whole
-- thing into a Folder of its own and destroys it afterwards.
--
-- IDEMPOTENT: an existing folder of the same name is destroyed first, the `Body.OUTFIT_NAME`
-- discipline -- a second build must never leave two lodges standing.
--
-- Returns the folder, the `TruckSpot` part and how many parts it made, so the budget is a CHECKED
-- claim (`lobby.spec` asserts `<= CONFIG.MAX_PARTS`) and not a promise.
function Build.build(
	container: Instance,
	anchor: Vector3,
	cfg,
	templates: Instance?
): (Instance, BasePart, BasePart, number)
	local existing = container:FindFirstChild(Data.FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	stats.parts = 0
	stats.solids = 0
	stats.models = 0
	stats.fallbacks = 0
	stats.strippedScripts = 0
	local folder = Instance.new("Folder")
	folder.Name = Data.FOLDER_NAME

	road(folder, anchor, cfg)
	fences(folder, anchor, cfg)
	treeLine(folder, anchor, cfg, templates)
	lodge(folder, anchor, cfg, templates)
	trucks(folder, anchor, cfg, templates)
	local marker = spot(folder, anchor, cfg)

	-- THE LODGE SPAWN. The engine's own lobby mechanism (`SpawnLocation` + `Player.RespawnLocation`,
	-- design section 14.1):
	--   * `Neutral = true` -- it belongs to no team, which is what a lobby spawn is;
	--   * `AllowTeamChangeOnTouch = false` -- the ENGINE must never write a team. `Match.Body.setTeam`
	--     is the one writer of `Player.Team` and a spawn pad that changed it would be a second one;
	--   * `Duration = 0` -- a `SpawnLocation` grants a 10-second ForceField by default, and a bubble
	--     round every player at the lodge is a thing Karen did not ask for.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = Data.SPAWN_NAME
	spawn.Size = cfg.SPAWN.SIZE
	spawn.CFrame = CFrame.new(anchor + cfg.SPAWN.OFFSET + Vector3.new(0, cfg.SPAWN.SIZE.Y / 2, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(86, 96, 74)
	spawn.Material = Enum.Material.Slate
	spawn.Transparency = 0.6
	spawn.CanQuery = false
	spawn.Parent = folder
	stats.parts += 1
	stats.solids += 1

	-- PARENTED LAST: one replication step for the whole lobby (`TestArena.build`'s own rule).
	folder.Parent = container
	stats.builds += 1
	return folder, marker, spawn, stats.parts
end

return Build
