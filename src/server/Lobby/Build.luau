--!strict
-- Lobby.Build: THE ONE WRITER OF EVERY PART IN `Workspace.Lobby` -- the lodge and its warm inside, the
-- trophy heads on its wall, the four parked trucks, the road and its fences, the tree line at the
-- field's edge, the marked circle, its sign and the lodge spawn.
--
-- KAREN chose the house herself: a **"Wooden log lodge"** -- logs, a porch, antlers over the door,
-- warm inside -- and *"Walk to a car"* for starting a hunt. The SHOP inside is task 178's counter
-- and sign, and since task 181 a SHOPKEEPER stands behind it with the `ProximityPrompt` that is now
-- the one way into the shop panel -- Karen, 2026-10-14: *"in lobby has to be a person bot who you
-- need to click E to get access to shop"*. He is the only thing in this tree with a Humanoid in it,
-- and the body and the clothes are both handed in (`Seams`), so this module reaches neither the
-- avatar service nor the outfit owner by itself.
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
-- THE PADS' GEOMETRY AND THEIR WORDS, BOTH PURE (task 182). `Pads.centreFor` is the ONE place
-- "where is pad 3" is computed -- this module and the owner both call it, which is what task 177
-- failed to do for the circle (the same `anchor + cfg.SPOT.OFFSET` expression lived in two files).
local Pads = require(script.Parent.Pads)

local Build = {}

-- WHAT A KEEPER IS MADE OF, AND WHO HANDS IT IN (task 181). Nothing in this module reaches the
-- avatar service or `Match.Body` by itself: the owner passes both in, which is the seam
-- `Bots.Rig.setSource` and `Bots.start({ dress = Body.dress })` already are, and it is what lets a
-- spec build the whole lobby with no web call and no outfit owner.
--
-- `rig = nil` MEANS NO KEEPER, and that is the deliberate default: a spec that has not asked for a
-- body does not get one built out from under it. The production path never leaves it nil --
-- `Lobby.tryBuild` passes `world.rig or Build.defaultRigSource`.
export type Seams = {
	rig: ((HumanoidDescription, Enum.HumanoidRigType) -> Model?)?,
	dress: ((Model, string, any, any) -> boolean)?,
	dressConfig: any?,
	-- WHERE THE GROUND IS, at any x/z (task 182). The world's own single reader -- the same
	-- `Data.groundAt` the owner uses to find the shelf and `Markers.setReaders` uses for the stand
	-- rings -- so a pad is laid on the surface the engine actually produced rather than on the one
	-- the arithmetic predicted. nil means "nobody said", and then the pure arithmetic stands.
	groundAt: ((number, number) -> number?)?,
	-- IS THE SHOP IN THIS BUILD AT ALL? The `SHOP` flag's value, read ONCE at the composition root
	-- and passed inward (CLAUDE.md, feature flags), because this module must not learn what a shop
	-- is. It decides one thing: whether the keeper's prompt is `Enabled`. With the shop off the
	-- panel is dead, and a live "Press E" over a man who answers nothing is worse than no prompt.
	-- nil is "nobody said", which is a prompt that works -- the state a spec builds in.
	shopOn: boolean?,
}

-- WHAT THE LAST BUILD MADE. The module never prints: a tool that `require`s it over StudioMCP gets a
-- sandboxed copy with empty state (measured, task 122), so the owner prints and this answers.
-- `models` is how many free-model templates were cloned, `fallbacks` how many were asked for and not
-- found (task 180), and `strippedScripts` how many script instances a template carried in -- all
-- three so "which build ran" is a number the spec and the boot's own log line can read, never a
-- belief.
--
-- `keepers` (task 181) is 1 when the shopkeeper's body was built and 0 when it was not -- a missing
-- rig source, a source that answered nil, a body with no root. `keeperDressed` is 1 when the outfit
-- owner RETURNED TRUE -- not merely when the call did not throw, which is what it used to mean and
-- is why it read `dressed=true` over an undressed man (review round 1, finding 2). Both are counted for `models`/`fallbacks`' stated reason: "the person at the
-- counter is there" must be a number the boot's log line and the spec can read, because a shop with
-- no keeper is a shop nobody can open since this task took the auto-open away.
local stats = {
	parts = 0,
	solids = 0,
	builds = 0,
	models = 0,
	fallbacks = 0,
	strippedScripts = 0,
	keepers = 0,
	keeperDressed = 0,
	-- HOW MANY TIMES A PAD'S BILLBOARD OR ATTRIBUTES WERE ACTUALLY WRITTEN (task 182). `Build.setPad`
	-- is edge-triggered, so a number that climbs with the owner's `scans` is the bug this counter
	-- exists to show -- `keeperTurns`' own rule, one owner over.
	padWrites = 0,
}

function Build.stats()
	return table.clone(stats)
end

-- THE KEEPER'S BODY, REMEMBERED so the owner's 10 Hz scan can turn his head without finding him
-- again, and so a spec can ask for it without a `Workspace`. It is an instance this module built and
-- not a decision: `Build.faceKeeper` is the one writer of his CFrame, and WHO he faces is
-- `Lobby.step`'s to decide.
local keeper: Model? = nil

function Build.keeper(): Model?
	if keeper ~= nil and keeper:IsDescendantOf(game) then
		return keeper
	end
	keeper = nil
	return nil
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

--
-- `seat` IS THE WHOLE DIFFERENCE BETWEEN A BUILDING AND A WALL MOUNT, and getting it wrong is not a
-- small error: a lodge must stand ON the ground, so its BOTTOM goes to `at.Y`, while a stag's head
-- hangs AT a height, so its CENTRE does. Seating a trophy put the head's base at the mount height --
-- its whole 5.4 studs ABOVE the plank it belongs on and, in a room 7.4 studs high, two and a half
-- studs through the ceiling (review round 1, finding 1).
local function cloneInstance(
	template: Instance,
	name: string,
	scale: number,
	at: Vector3,
	yaw: number,
	parent: Instance,
	cosmetic: boolean,
	seat: boolean
): Instance
	local made = template:Clone()
	made.Name = name
	stats.strippedScripts += scriptsIn(made)
	if made:IsA("Model") then
		if scale ~= 1 then
			made:ScaleTo(scale)
		end
		made:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0))
		if seat then
			sitOnShelf(made :: Model, at.Y)
		else
			-- CENTRED ON THE MOUNT, measured rather than assumed: a Model's pivot is its
			-- bounding-box centre only while nobody has set a PrimaryPart, and a free model may
			-- have one.
			-- ALL THREE AXES, not just the height (review round 2, note): a replacement head model
			-- with a `PrimaryPart` has a pivot that is not its bounding-box centre, and correcting
			-- only Y would hang it off its plaque sideways.
			local model = made :: Model
			local box = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + (at - box.Position))
		end
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

-- THE SAME THING, BY TEMPLATE NAME. A missing template is not an error: it answers nil and the caller
-- builds task 177's version.
local function clone(
	templates: Instance?,
	key: string,
	name: string,
	scale: number,
	at: Vector3,
	yaw: number,
	parent: Instance,
	cosmetic: boolean,
	seat: boolean?
): Instance?
	if templates == nil then
		return nil
	end
	local template = (templates :: Instance):FindFirstChild(key)
	if template == nil then
		stats.fallbacks += 1
		return nil
	end
	return cloneInstance(template, name, scale, at, yaw, parent, cosmetic, seat ~= false)
end

-- ---------------------------------------------------------------- the lodge

-- THE ROOM INSIDE THE LODGE, whichever lodge got built. Everything that hangs on a wall or stands on
-- the floor is placed against THIS and never against `cfg.LODGE.SIZE`, because the free model's room
-- (19.6 x 19.6 x 7.4) and task 177's (38 x 26 x 9) are different rectangles and a constant offset
-- can only be right for one of them.
export type Room = { centre: Vector3, halfX: number, halfZ: number, height: number }

-- PURE, AND EXPORTED, so `lobby.spec` can bound a trophy against the rectangle the mount actually
-- used instead of against the lodge's whole footprint. Review round 1, finding 3: a footprint bound
-- is ten studs away from the wall and cannot see a plaque a quarter of a stud past it, which is
-- exactly the inverted-yaw bug it was written to catch.
function Build.roomFor(anchor: Vector3, cfg, fromModel: boolean): Room
	local origin = anchor + cfg.LODGE.OFFSET
	if fromModel then
		local model = cfg.LODGE.MODEL
		local scale = model.SCALE
		return {
			centre = Vector3.new(
				origin.X + model.ROOM.CENTRE.X * scale,
				origin.Y + model.ROOM.CENTRE.Y * scale,
				origin.Z + model.ROOM.CENTRE.Z * scale
			),
			halfX = model.ROOM.HALF_X * scale,
			halfZ = model.ROOM.HALF_Z * scale,
			height = (model.ROOM.CEILING_Y - model.ROOM.CENTRE.Y) * scale,
		}
	end
	return {
		centre = Vector3.new(origin.X, origin.Y + 1, origin.Z),
		halfX = cfg.LODGE.SIZE.X / 2 - 1,
		halfZ = cfg.LODGE.SIZE.Z / 2 - 1,
		height = cfg.LODGE.SIZE.Y,
	}
end

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
		-- WHICH WALL, AS THE ONE PLACE THE FOUR NAMES TURN INTO GEOMETRY.
		--
		-- `yaw` IS THE DIRECTION THE HEAD LOOKS, AND EVERY OFFSET BELOW RUNS ALONG IT. A CFrame's
		-- LookVector is its own -Z, so `CFrame.Angles(0, 0, 0)` looks at -Z (north wall -> south) and
		-- `CFrame.Angles(0, math.pi / 2, 0)` looks at -X (east wall -> west). Getting that backwards
		-- does not fail, it hangs all three heads on the OUTSIDE of the lodge -- which is exactly
		-- what the first inside shot showed, with the plaques 0.24 studs past the wall plane and the
		-- heads a stud past that, in the open air (task 180, rule 5).
		local at, yaw
		if mount.wall == "north" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z + room.halfZ), 0
		elseif mount.wall == "south" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z - room.halfZ), math.pi
		elseif mount.wall == "west" then
			at, yaw = Vector3.new(room.centre.X - room.halfX, 0, room.centre.Z + mount.along), -math.pi / 2
		else
			at, yaw = Vector3.new(room.centre.X + room.halfX, 0, room.centre.Z + mount.along), math.pi / 2
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
			true,
			false -- a wall mount hangs AT a height; it does not stand on the floor
		)
		if head ~= nil and head:IsA("Model") then
			-- UNDER THE CEILING, MEASURED OFF THE HEAD ITSELF. The deer model is 5.4 studs tall and
			-- the free lodge's room is 7.4, so a head centred at 4.4 would put its antlers through
			-- the roof -- the same thing `stackHeight` clamps the chimney for, three functions up.
			local antlers = head :: Model
			local box, size = antlers:GetBoundingBox()
			local ceiling = room.centre.Y + room.height - 0.3
			local wanted = math.min(box.Position.Y, ceiling - size.Y / 2)
			if wanted < box.Position.Y then
				antlers:PivotTo(antlers:GetPivot() + Vector3.new(0, wanted - box.Position.Y, 0))
			end
		end
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

-- ---------------------------------------------------------------- the shopkeeper (task 181)

-- THE DEFAULT BODY: one engine call is a complete R15 rig with a Humanoid, so there is no hand-built
-- rig, no fifteen `Motor6D`s and no `.rbxm` (banned). An EMPTY `HumanoidDescription` on purpose --
-- no bundle, no clothing, nothing to fetch -- because the outfit owner paints the green and puts the
-- hat on, and a described outfit would be a second answer to what this game's people look like.
-- `Bots.Rig`'s own default, taken whole and for its own stated reasons (rule 2).
--   Players:CreateHumanoidModelFromDescription
--     https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescription
--
-- MAY YIELD: the call is documented to load assets. It happens ONCE, at lobby build, and that cost
-- is already inside the figure `Lobby.stats().buildMs` reports.
function Build.defaultRigSource(description: HumanoidDescription, rigType: Enum.HumanoidRigType): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, rigType)
	end)
	if not ok or typeof(model) ~= "Instance" then
		return nil
	end
	return model :: Model
end

-- THE MAN BEHIND THE COUNTER, and the only thing in `Workspace.Lobby` with a Humanoid in it.
--
-- KAREN, 2026-10-14: *"in lobby has to be a person bot who you need to click E to get access to
-- shop"*. So he is a body, and the `ProximityPrompt` on him is the ONE way into the shop panel since
-- this task took task 178's walk-up-and-it-opens away.
--
-- HE IS NOT A THING THE GAME CAN TOUCH. Every part: `CanCollide = false` so nobody can push him or
-- be blocked by him, `CanQuery = false` for the reason this file already states twice (*a slab that
-- stops a pellet changes what the shot hit*), `CanTouch = false` so he fires nothing. His ROOT is
-- anchored and his limbs are not, which is `Bots.Rig.place(.., anchored = true)`'s arrangement: the
-- anchor is what stops anything nudging him off his spot, and the limbs stay on their joints so the
-- idle clip can move them.
--
-- THE PROMPT HANGS ON AN ATTACHMENT AT HEAD HEIGHT AND THAT IS GEOMETRY, NOT TASTE: the counter is
-- 3.5 studs tall and queryable, so a line-of-sight ray aimed at a root part 3 studs up would be
-- stopped by the till itself and the prompt would never appear for the one person standing where he
-- is supposed to stand.
--
-- IT RETURNS nil RATHER THAN ERRORING, the rule `clone` already follows: no rig source, a source
-- that answered nothing, a body with no root -- the lodge still gets built, `stats.keepers` stays 0,
-- and the boot's own log line is what says so.
local function shopkeeper(shop: Instance, counterAt: Vector3, floorY: number, cfg, seams: Seams?): Model?
	local make = if seams ~= nil then seams.rig else nil
	if make == nil then
		return nil
	end
	local keep = cfg.LODGE.KEEPER
	local ok, made = pcall(make :: any, Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	if not ok or typeof(made) ~= "Instance" or not (made :: Instance):IsA("Model") then
		return nil
	end
	local body = made :: Model
	body.Name = Data.KEEPER_NAME
	-- BELT AND BRACES, the same line `cloneInstance` runs over a free model: an avatar rig is not a
	-- place a script hides, but CLAUDE.md's rule is absolute and the lobby spec asserts it.
	stats.strippedScripts += scriptsIn(body)
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	local found = body.PrimaryPart or body:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not (found and found:IsA("BasePart")) then
		body:Destroy()
		return nil
	end
	local root = found :: BasePart
	body.PrimaryPart = root

	-- THE VENDOR'S OWN SENTENCE ABOUT A STATIC NPC, as far as the outfit allows: the class has to
	-- stay, because `Humanoid:AddAccessory` is how the hat goes on, so what goes is the WORK.
	-- `Bots.Rig.prepare`'s stander branch, line for line.
	local man = humanoid :: Humanoid
	man.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	man.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	man.WalkSpeed = 0
	man.JumpHeight = 0
	man.JumpPower = 0
	man.EvaluateStateMachine = false
	for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
		if state ~= Enum.HumanoidStateType.None then
			man:SetStateEnabled(state, false)
		end
	end

	for _, descendant in ipairs(body:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			stats.parts += 1
		end
	end
	root.Anchored = true

	-- WHERE HE STANDS AND WHICH WAY HE LOOKS: behind the till, facing the room a customer walks in
	-- from (-Z is the door side, which is the way task 177's lodge and the free model both face).
	local standAt = Vector3.new(counterAt.X, floorY + keep.ROOT_HEIGHT, counterAt.Z + keep.BEHIND_STUDS)
	body.Parent = shop
	body:PivotTo(CFrame.lookAt(standAt, standAt - Vector3.new(0, 0, 10)))

	-- THE PROMPT. Every property is a number in `Lobby.CONFIG.LODGE.KEEPER.PROMPT` with its reason
	-- in `docs/research/2026-10-14-the-shopkeeper.md` section 4 -- and ONE property set covers a
	-- keyboard, a gamepad and a thumb, which is the whole reason this beats the key binding task 178
	-- had.
	--   ProximityPrompt  https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
	local at = Instance.new("Attachment")
	at.Name = "ShopPromptAt"
	at.Position = Vector3.new(0, keep.PROMPT_HEIGHT, 0)
	at.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Data.PROMPT_NAME
	prompt.ActionText = keep.PROMPT.ACTION_TEXT
	prompt.ObjectText = keep.PROMPT.OBJECT_TEXT
	prompt.KeyboardKeyCode = keep.PROMPT.KEYBOARD_KEY
	prompt.GamepadKeyCode = keep.PROMPT.GAMEPAD_KEY
	prompt.HoldDuration = keep.PROMPT.HOLD_SECONDS
	prompt.MaxActivationDistance = keep.PROMPT.MAX_DISTANCE
	prompt.RequiresLineOfSight = keep.PROMPT.REQUIRES_LINE_OF_SIGHT
	prompt.Enabled = if seams ~= nil and seams.shopOn ~= nil then seams.shopOn == true else true
	prompt.Parent = at

	-- THE CLOTHES, THROUGH THE ONE DRESSING PATH IN THIS REPOSITORY (`Match.Body.dress`, handed in
	-- by the composition root exactly as `Bots.start({ dress = Body.dress })` hands it in). He wears
	-- the hunter's green with task 178's `Look` for a hat of his own, so a lodge keeper is one
	-- existing call with one existing parameter and this module never learns what an outfit is.
	if seams ~= nil and seams.dress ~= nil then
		-- BOTH ANSWERS, AND THE SECOND ONE IS THE ONE THAT MEANS ANYTHING (review round 1, finding
		-- 2). `pcall`'s flag only says the call did not throw; `Body.dress` returns FALSE for
		-- "there was nothing I could put on him", which is exactly the state finding 1 was in while
		-- this counter -- and the boot's `dressed=true` -- said otherwise.
		local called, answered =
			pcall(seams.dress :: any, body, keep.TEAM, seams.dressConfig, { hatColor = keep.HAT_COLOR })
		if called and answered == true then
			stats.keeperDressed = 1
		end
		-- The accessories the outfit owner put on are parts too, and they are cosmetic by the same
		-- rule as the rest of him.
		for _, descendant in ipairs(body:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= root then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
	end

	-- THE IDLE, PLAYED ONCE AND NEVER WRITTEN AGAIN -- there is no clock in this system. The id is
	-- `Bots.Rig.CLIPS.idle`, the same asset every drive bot stands in, written in
	-- `Lobby.CONFIG` rather than required out of `Bots` so the lobby does not depend on the drive's
	-- owner. `Rig.loadClips`' measured caveat applies and is repeated: a track that LOADS is
	-- evidence the call succeeded, not that the body is moving, so the screenshot is what says so.
	local animator = man:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator");
		(animator :: Animator).Parent = man
	end
	local animation = Instance.new("Animation")
	animation.Name = "Idle"
	animation.AnimationId = keep.IDLE_ANIMATION
	animation.Parent = man
	pcall(function()
		local track = (animator :: Animator):LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play()
	end)

	stats.keepers = 1
	keeper = body
	return body
end

-- WHERE HE IS STANDING, or nil when there is nobody there -- the owner's test for "is there a
-- keeper to turn at all", and the one thing it needs to measure who is nearest to him.
function Build.keeperPosition(): Vector3?
	local body = Build.keeper()
	local root = if body ~= nil then (body :: Model).PrimaryPart else nil
	return if root ~= nil then (root :: BasePart).Position else nil
end

-- WHICH WAY THE KEEPER LOOKS, and THE ONLY WRITER OF HIS CFRAME AFTER THE BUILD. The owner decides
-- WHO he faces (`Lobby.step` already walks every occupant's root on its 10 Hz scan, so the nearest
-- one is free) and this writes it -- which keeps *"the one writer of every part in `Workspace.Lobby`"*
-- true with no second module touching a body.
--
-- YAW ONLY, and only when it MOVED more than the epsilon: a man standing still at the counter costs
-- one subtraction per scan and no write at all. `nil` means "nobody is near" and he goes back to
-- facing the room, which is the same rule his build gives him.
--
-- Returns whether it actually wrote, so the spec asserts the epsilon rather than the intention.
function Build.faceKeeper(at: Vector3?, cfg): boolean
	local body = Build.keeper()
	if body == nil then
		return false
	end
	local keep = cfg.LODGE.KEEPER
	if keep.LOOK_AT ~= true then
		return false
	end
	local root = (body :: Model).PrimaryPart
	if root == nil then
		return false
	end
	local here = (root :: BasePart).Position
	local toward = Vector3.new(here.X, here.Y, here.Z - 10)
	if at ~= nil then
		local flat = Vector3.new((at :: Vector3).X - here.X, 0, (at :: Vector3).Z - here.Z)
		if flat.Magnitude > 0.1 and flat.Magnitude <= keep.FACE_STUDS then
			toward = Vector3.new(here.X + flat.X, here.Y, here.Z + flat.Z)
		end
	end
	local wanted = CFrame.lookAt(here, toward)
	-- THE ANGLE BETWEEN THE TWO FACINGS, in degrees, from the dot product of the two flat look
	-- vectors -- which is cheaper and better behaved than two `atan2`s subtracted across the wrap.
	local a, b = (root :: BasePart).CFrame.LookVector, wanted.LookVector
	local dot = math.clamp(a.X * b.X + a.Z * b.Z, -1, 1)
	if math.deg(math.acos(dot)) < keep.FACE_EPSILON_DEGREES then
		return false
	end
	(body :: Model):PivotTo(wanted)
	return true
end

-- THE WARM INSIDE: a stone fireplace with ONE `PointLight`, a table, two benches, and task 178's
-- shop counter -- with, since task 181, a man standing behind it.  Nothing here is animated per
-- frame and nothing is written per frame: the keeper's idle is played once, at build, and his head
-- is turned by the owner's own 10 Hz scan.
local function interior(folder: Instance, room: Room, cfg, templates: Instance?, seams: Seams?)
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
	-- CLAMPED SO IT CANNOT COME THROUGH THE WALL (review round 1, note). `halfX / 2` plus half a
	-- 12-stud counter is 10.9 studs in the free model's 9.8-stud half-room, so the till's east end
	-- stood a stud outside the lodge.
	local counterX = math.min(room.halfX / 2, math.max(0, room.halfX - cfg.LODGE.COUNTER.X / 2 - 0.3))
	local counterAt = Vector3.new(origin.X + counterX, origin.Y + cfg.LODGE.COUNTER.Y / 2, backZ - 1)
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
	-- THE MAN BEHIND IT (task 181). `origin.Y` is the floor the counter stands on, which is what he
	-- stands on too -- the one number, read in one place.
	shopkeeper(shop, counterAt, origin.Y, cfg, seams)

	trophies(inside, room, cfg, templates)
end

-- THE LODGE, AND WHICH OF THE TWO GOT BUILT IS DECIDED IN ONE PLACE.
--
-- Karen, 2026-10-14: *"we need better house we can use free models"*. So the FREE MODEL is first
-- choice and task 177's parts lodge is what happens when it is not there -- a missing template, a
-- renamed folder, a place that has never had the models inserted (the DEV place is exactly that).
-- Both branches end the same way, with the same warm inside and the same shop counter hung on the
-- same measured room, so nothing downstream has to ask which one it got.
local function lodge(container: Instance, anchor: Vector3, cfg, templates: Instance?, seams: Seams?): Instance
	local folder = Instance.new("Folder")
	folder.Name = "Lodge"
	local origin = anchor + cfg.LODGE.OFFSET
	local size = cfg.LODGE.SIZE
	local halfX, halfZ = size.X / 2, size.Z / 2

	local model = cfg.LODGE.MODEL
	local built = clone(templates, Data.TEMPLATE.LODGE, "House", model.SCALE, origin, model.YAW_RADIANS, folder, false)
	if built ~= nil then
		interior(folder, Build.roomFor(anchor, cfg, true), cfg, templates, seams)
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

	interior(folder, Build.roomFor(anchor, cfg, false), cfg, templates, seams)
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

-- ---------------------------------------------------------------- the four truck pads (task 182)

-- KAREN, 2026-10-14: *"has to be coloroude circle like in all games or rectangle where people stand
-- ... and can be several truck like 4 of them nicly aligned next ot each other and you come to truck
-- back rectangle"*.
--
-- IT REPLACES TASK 177'S SINGLE CIRCLE, archived with its reason in
-- `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7).
--
-- THE GLOWING EDGE IS `SPOT.RING`'S LANGUAGE WITH CORNERS INSTEAD OF A CURVE -- neon, lifted clear of
-- the deck, in the pad's own colour -- so the lobby's pads and the hunter's stand circle are still the
-- same piece of UI language. Two marks drawn two different ways would teach a player two things.
--
-- NO GROUND READER, and it is the circle's own stated reason: these rectangles lie on the lobby's own
-- FLAT shelf, whose height is one number, so a raycast per corner would be measuring a surface this
-- system built itself.

-- THE PADS, REMEMBERED, for `Build.keeper`'s stated reason: the owner's 10 Hz scan writes a
-- billboard and two attributes without finding the part again, and a spec can ask for one without a
-- `Workspace`. They are instances this module built and not decisions -- `Build.setPad` is the one
-- writer of what a pad SAYS, and WHAT it says is `Lobby.step`'s to decide, which is
-- `Build.faceKeeper`'s arrangement exactly.
local padParts: { [number]: BasePart } = {}

function Build.padPart(index: number): BasePart?
	local held = padParts[index]
	if held ~= nil and held:IsDescendantOf(game) then
		return held
	end
	padParts[index] = nil
	return nil
end

-- ONE PAD: a coloured rectangle on the ground, a glowing edge round it, and a billboard over it.
--
-- THE DECK *IS* THE NAMED PART. There is no second invisible marker: the part the rule reads, the
-- part the client finds, the part the attributes live on and the thing Karen looks at are one
-- instance, so they cannot drift apart. `CanQuery` and `CanTouch` are false -- a pellet must not stop
-- on it and `Touched` must never fire, because presence here is arithmetic (`Join.withinRect`) -- and
-- `CanCollide` is false so a player stands on the road under it rather than stepping up onto a kerb.
local function pad(
	container: Instance,
	anchor: Vector3,
	index: number,
	cfg,
	groundAt: ((number, number) -> number?)?
): BasePart
	local config = cfg.PADS
	local folder = Instance.new("Folder")
	folder.Name = string.format("Pad%d", index)
	local centre = Pads.centreFor(anchor, index, cfg)
	local size = config.SIZE
	-- ...AND THEN THE Y IS TAKEN FROM THE GROUND THAT IS ACTUALLY THERE, which is the one thing
	-- `Pads.centreFor` cannot know and the one correction this task had to make after LOOKING at it
	-- (rule 5).
	--
	-- MEASURED, 2026-10-14, in the live Forest Test place: every pad's top came out at 149.828 and
	-- the terrain under it at 150.000 -- the four rectangles were 0.17 studs UNDERGROUND and
	-- invisible, with only their billboards showing. The design's arithmetic (`shelfY +
	-- ROAD.THICK_STUDS + LIFT_STUDS`) assumed the surface a pad lands on is the nominal shelf, and
	-- ROBLOX TERRAIN IS VOXELISED: `Field.fill` asks for a block whose top is `shelfY` and the
	-- surface the engine actually produces is rounded to its own grid -- here 0.75 studs higher. A
	-- constant lift cannot fix that, because the rounding is a property of where the block fell and
	-- not a number this system chose.
	--
	-- SO THE PAD SITS ON WHAT IS MEASURED, which is `Markers.setReaders`' own pattern for the stand
	-- rings and the same `world.groundAt` the owner already uses to find the shelf. A world that
	-- hands in no reader keeps the pure arithmetic, which is what every spec builds with and what
	-- makes the fallback a stated branch rather than a crash.
	--
	-- THIS IS TASK 177'S ROUND-1 FINDING, A SECOND TIME AND AGAINST A DIFFERENT SURFACE: the ring was
	-- buried in the road slab, these were buried in the terrain. Both were found by looking at a
	-- picture, which is why rule 5 exists.
	if groundAt ~= nil then
		local ok, measured = pcall(groundAt, centre.X, centre.Z)
		if ok and type(measured) == "number" then
			centre = Vector3.new(centre.X, (measured :: number) + config.LIFT_STUDS - size.Y / 2, centre.Z)
		end
	end
	-- WRAPPED, so a fifth bay cannot index past the end of the colour list.
	local colour = config.COLOURS[(index - 1) % #config.COLOURS + 1]

	local deck = part(
		Data.padPartName(index) or string.format("Pad%d", index),
		size,
		CFrame.new(centre),
		colour,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	deck.Transparency = config.TRANSPARENCY

	-- THE GLOWING EDGE: four neon bars, the long pair along x and the short pair along z, each
	-- standing ON the deck's top rather than inside it. The deck's top is
	-- `centre.Y + SIZE.Y / 2`, which is the one surface in this build that is above every yard slab.
	local topY = centre.Y + size.Y / 2
	local railY = topY + config.RIM_HEIGHT_STUDS / 2
	local halfX, halfZ = size.X / 2, size.Z / 2
	local rails = {
		{ name = "RimN", size = Vector3.new(size.X, config.RIM_HEIGHT_STUDS, config.RIM_STUDS), dx = 0, dz = halfZ },
		{ name = "RimS", size = Vector3.new(size.X, config.RIM_HEIGHT_STUDS, config.RIM_STUDS), dx = 0, dz = -halfZ },
		{ name = "RimE", size = Vector3.new(config.RIM_STUDS, config.RIM_HEIGHT_STUDS, size.Z), dx = halfX, dz = 0 },
		{ name = "RimW", size = Vector3.new(config.RIM_STUDS, config.RIM_HEIGHT_STUDS, size.Z), dx = -halfX, dz = 0 },
	}
	for _, rail in ipairs(rails) do
		part(
			rail.name,
			rail.size,
			CFrame.new(centre.X + rail.dx, railY, centre.Z + rail.dz),
			colour,
			Enum.Material.Neon,
			false,
			folder
		)
	end

	-- THE BOARD OVER IT -- the community pad's own arrangement (note section 2c): the count and the
	-- state are drawn where the man walking across the yard can read them, in the WORLD, and not on
	-- his screen. The Hud owns the screen (`docs/design/hud-clarity.md`) and this is the one thing in
	-- this task that is deliberately not on it.
	--
	--   BillboardGui  https://create.roblox.com/docs/reference/engine/classes/BillboardGui
	--     `Adornee` + `StudsOffsetWorldSpace` hangs it over the pad with no script and nothing
	--     written per frame, and `MaxDistance` is a property rather than a distance check of ours.
	--
	-- `AlwaysOnTop = false`, so the truck in front of it occludes it properly and the board is part of
	-- the world rather than painted over everything.
	local board = Instance.new("BillboardGui")
	board.Name = "Board"
	board.Adornee = deck
	board.Size = UDim2.fromOffset(config.BILLBOARD.SIZE_PX.X, config.BILLBOARD.SIZE_PX.Y)
	board.StudsOffsetWorldSpace = Vector3.new(0, config.BILLBOARD.OFFSET_STUDS, 0)
	board.MaxDistance = config.BILLBOARD.MAX_DISTANCE_STUDS
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.Parent = deck

	local function boardLabel(name: string, textSize: number, y: number, tint: Color3, line: string)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Code
		text.TextSize = textSize
		text.TextColor3 = tint
		text.Text = line
		text.Position = UDim2.fromOffset(0, y)
		text.Size = UDim2.new(1, 0, 0, textSize + 6)
		-- THE SAME BLACK OUTLINE every label in this game wears: over a sunlit field a thin `Code`
		-- glyph with no stroke is the half of the text that disappears first (`ShopPanel.label`).
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = text
		text.Parent = board
	end
	-- THE BOARD SAYS SOMETHING FROM THE FIRST FRAME, AND THE ATTRIBUTES ARE SET AT BUILD. Written
	-- here rather than left to the owner's first scan, for two reasons: an empty billboard over a
	-- coloured rectangle reads as broken rather than as empty, and a pad that is BUILT is a pad whose
	-- state a client can already read -- so `Build.build` into a spec's own folder is a complete pad
	-- and not a half-built one waiting for a scan that spec never runs.
	boardLabel("Truck", config.BILLBOARD.TRUCK_PX, 0, colour, string.format(config.BILLBOARD.TRUCK, index))
	boardLabel(
		"Count",
		config.BILLBOARD.COUNT_PX,
		config.BILLBOARD.TRUCK_PX + 6,
		Color3.fromRGB(246, 240, 230),
		string.format(config.BILLBOARD.COUNT_UNSET, 0)
	)
	deck:SetAttribute(Data.PAD_STATE_ATTRIBUTE, Data.PAD_STATE.EMPTY)

	folder.Parent = container
	padParts[index] = deck
	return deck
end

-- ALL FOUR PADS, one behind each bay, in `TRUCK.COUNT`'s own loop -- so four trucks and three pads
-- cannot happen. Returns them in pad order, and `Build.build` hands pad 1 back as the marker its
-- signature has always carried.
local function pads(container: Instance, anchor: Vector3, cfg, groundAt: ((number, number) -> number?)?): { BasePart }
	local folder = Instance.new("Folder")
	folder.Name = "Pads"
	local made: { BasePart } = {}
	for index = 1, cfg.TRUCK.COUNT do
		table.insert(made, pad(folder, anchor, index, cfg, groundAt))
	end
	folder.Parent = container
	return made
end

Build.pads = pads

-- THE ONE WRITER OF WHAT A PAD SAYS AND OF ITS TWO ATTRIBUTES, and it is here rather than in the
-- owner because this module is *"the one writer of every part in `Workspace.Lobby`"* -- an attribute
-- on one of its parts included. `Build.faceKeeper`'s arrangement for the same reason: the owner
-- DECIDES (it holds the pad states) and this writes.
--
-- IT RETURNS WHETHER IT WROTE ANYTHING, so `stats.padWrites` counts EDGES. A pad standing empty
-- costs four comparisons a scan and no replication at all, and a counter that climbs with the
-- owner's `scans` is a bug `lobby_live.spec` catches.
--
-- THE TWO ATTRIBUTES ARE THE WHOLE OUTBOUND WIRE (design section 8.1): `DHPadState` is the state
-- word and `DHPadFirst` is the userId who may pick, which is the dialog's entire visibility rule.
function Build.setPad(index: number, state: string, firstUserId: number?, count: number, size: number?): boolean
	local deck = Build.padPart(index)
	if deck == nil then
		return false
	end
	local board = (deck :: BasePart):FindFirstChild("Board")
	local truckLabel = if board then board:FindFirstChild("Truck") else nil
	local countLabel = if board then board:FindFirstChild("Count") else nil
	if
		not (truckLabel ~= nil and truckLabel:IsA("TextLabel") and countLabel ~= nil and countLabel:IsA("TextLabel"))
	then
		return false
	end
	local cfg = Data.CONFIG
	local words = cfg.PADS.BILLBOARD
	local truckText = string.format(words.TRUCK, index)
	local countText = if size == nil
		then string.format(words.COUNT_UNSET, count)
		else string.format(words.COUNT, count, size :: number)
	local wrote = false
	if (truckLabel :: TextLabel).Text ~= truckText then
		(truckLabel :: TextLabel).Text = truckText
		wrote = true
	end
	if (countLabel :: TextLabel).Text ~= countText then
		(countLabel :: TextLabel).Text = countText
		wrote = true
	end
	if (deck :: BasePart):GetAttribute(Data.PAD_STATE_ATTRIBUTE) ~= state then
		(deck :: BasePart):SetAttribute(Data.PAD_STATE_ATTRIBUTE, state)
		wrote = true
	end
	if (deck :: BasePart):GetAttribute(Data.PAD_FIRST_ATTRIBUTE) ~= firstUserId then
		(deck :: BasePart):SetAttribute(Data.PAD_FIRST_ATTRIBUTE, firstUserId)
		wrote = true
	end
	if wrote then
		stats.padWrites += 1
	end
	return wrote
end

-- WHAT IS ACTUALLY WRITTEN OVER PAD n, for a spec and a console probe to read instead of guessing --
-- `ShopPanel.rowText`'s seam, on the server's side of the game.
function Build.padLabel(index: number): (string, string)
	local deck = Build.padPart(index)
	local board = if deck then (deck :: BasePart):FindFirstChild("Board") else nil
	local truckLabel = if board then board:FindFirstChild("Truck") else nil
	local countLabel = if board then board:FindFirstChild("Count") else nil
	return (if truckLabel ~= nil and truckLabel:IsA("TextLabel") then (truckLabel :: TextLabel).Text else ""),
		(if countLabel ~= nil and countLabel:IsA("TextLabel") then (countLabel :: TextLabel).Text else "")
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
	-- LAID ON THE SHELF, NOT IN IT, AND THAT WAS PHOTOGRAPHED. The first build centred these slabs
	-- ON `anchor.Y`, so half of each was underground and the terrain's grass blades stood through the
	-- other half: the shot came back with a field and NO ROAD, with the player standing on it.
	-- `FIELD.PADS` now puts a blade-free block under the corridor as well -- the two together are the
	-- fix and either one alone is not.
	local top = anchor.Y + spec.THICK_STUDS / 2
	part(
		"Lane",
		Vector3.new(spec.WIDTH_STUDS, spec.THICK_STUDS, length),
		CFrame.new(anchor.X + spec.CENTRE_X, top, anchor.Z + midZ),
		spec.COLOR,
		spec.MATERIAL,
		false,
		folder
	)
	for index, side in ipairs({ -1, 1 }) do
		part(
			string.format("Verge%d", index),
			Vector3.new(spec.VERGE_STUDS, spec.THICK_STUDS, length),
			CFrame.new(
				anchor.X + spec.CENTRE_X + side * (spec.WIDTH_STUDS + spec.VERGE_STUDS) / 2,
				top - 0.05,
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
		Vector3.new(math.abs(cfg.TRUCK.OFFSET.X - spec.CENTRE_X) + bays + 34, spec.THICK_STUDS, 44),
		CFrame.new(anchor.X + (spec.CENTRE_X + cfg.TRUCK.OFFSET.X + bays) / 2, top, anchor.Z + cfg.TRUCK.OFFSET.Z),
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
	-- HOW MANY POSTS FIT BETWEEN THE TWO BOUNDS, rather than a count that can walk into the house
	-- (review round 2). `TO_Z` is south of the yard, so the line stops before the yard, the porch,
	-- the spawn pad and the lodge -- which is the *"gap at the yard"* `CONFIG.FENCE` always promised.
	local posts = math.max(2, math.floor((spec.TO_Z - spec.FROM_Z) / spec.SPACING_STUDS) + 1)
	for _, side in ipairs({ -1, 1 }) do
		local x = anchor.X + cfg.ROAD.CENTRE_X + side * spec.OFF_ROAD_STUDS
		local tag = if side < 0 then "W" else "E"
		for index = 1, posts do
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
			if index < posts then
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
		-- NOT IN THE ROAD. The arc runs from one side of the yard round the south to the other, and
		-- the road leaves through the south, so two of the thirty would otherwise stand in it. A
		-- tree in the road is not scenery.
		local offRoad = math.abs(at.X - (anchor.X + cfg.ROAD.CENTRE_X))
		if offRoad < cfg.ROAD.WIDTH_STUDS / 2 + cfg.ROAD.VERGE_STUDS + 4 and at.Z < anchor.Z + cfg.ROAD.FROM_Z then
			continue
		end
		-- ...NOR IN THE YARD (review round 2, note): the arc's eastern end swings past the fourth
		-- truck bay, and a spruce between the bays is the same mistake as a spruce in the road.
		local bays = (cfg.TRUCK.COUNT - 1) * cfg.TRUCK.BAY_GAP_STUDS
		local yardMidX = anchor.X + (cfg.ROAD.CENTRE_X + cfg.TRUCK.OFFSET.X + bays) / 2
		local yardHalfX = (math.abs(cfg.TRUCK.OFFSET.X - cfg.ROAD.CENTRE_X) + bays + 34) / 2
		local yardZ = anchor.Z + cfg.TRUCK.OFFSET.Z
		if math.abs(at.X - yardMidX) < yardHalfX + 4 and math.abs(at.Z - yardZ) < 26 then
			continue
		end
		-- THROUGH `cloneInstance` AND NOT BY HAND (review round 1, note). The hand-rolled walk here
		-- used `GetDescendants`, which never visits the instance itself, so a `Trees` child that was
		-- a Part rather than a Model came out UNANCHORED AND QUERYABLE -- the one thing this
		-- function's own comment says must not happen.
		local kind = kinds[rng:NextInteger(1, #kinds)]
		cloneInstance(
			kind,
			string.format("Tree%02d", index),
			rng:NextNumber(spec.SCALE[1], spec.SCALE[2]),
			Vector3.new(at.X, anchor.Y, at.Z),
			rng:NextNumber(0, math.pi * 2),
			folder,
			true,
			true
		)
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
	templates: Instance?,
	seams: Seams?
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
	stats.keepers = 0
	stats.keeperDressed = 0
	stats.padWrites = 0
	-- THE OLD KEEPER WENT WITH THE OLD FOLDER. Dropped here rather than relied on, so a rebuild can
	-- never leave `Build.faceKeeper` turning a body that is no longer in the DataModel.
	keeper = nil
	-- ...AND SO DID THE OLD PADS (task 182), for the same reason: `Build.setPad` must never write a
	-- billboard on a deck that is no longer in the DataModel, which is what `padPart`'s own
	-- `IsDescendantOf` check would otherwise have to catch one scan late.
	table.clear(padParts)
	local folder = Instance.new("Folder")
	folder.Name = Data.FOLDER_NAME

	road(folder, anchor, cfg)
	fences(folder, anchor, cfg)
	treeLine(folder, anchor, cfg, templates)
	lodge(folder, anchor, cfg, templates, seams)
	trucks(folder, anchor, cfg, templates)
	-- FOUR PADS, AND PAD 1 IS THE `marker` THIS FUNCTION HAS ALWAYS RETURNED (task 182): its part is
	-- still named `Lobby.SPOT_NAME`, so `Lobby.spotPart`, the Hud's chevron and the Director's
	-- `smoke.sh` all keep working with no edit.
	-- THE WORLD'S OWN GROUND READER, handed through so each pad sits on the surface that is really
	-- there rather than on the one the arithmetic predicted (see `pad`). nil is legal and is what
	-- every spec uses.
	local made = pads(folder, anchor, cfg, (seams or {}).groundAt)
	local marker = made[1]

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
