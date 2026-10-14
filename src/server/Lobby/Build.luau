--!strict
-- Lobby.Build: THE ONE WRITER OF EVERY PART IN `Workspace.Lobby` -- the log lodge, its porch and its
-- warm inside, the hunting truck, the dirt track, the marked circle, its sign and the lodge spawn.
--
-- KAREN chose the house herself: a **"Wooden log lodge"** -- logs, a porch, antlers over the door,
-- warm inside -- and *"Walk to a car"* for starting a hunt. The SHOP inside is task 178: this builds
-- the empty counter and a placeholder sign and nothing more.
--
-- IT IS A PARTS BUILD, AND THE REASON IS WRITTEN DOWN SO IT IS NOT RE-LITIGATED (research note
-- section 4). A free Creator Store model (`InsertService:LoadAsset`) needs a hand check for Scripts
-- -- CLAUDE.md forbids script-like instances outside Rojo-owned paths, and a free model is a common
-- place to hide one -- plus an `assets/uploads.json` row carrying **the text of Karen's OK**; a Meshy
-- lodge needs a brief, a run, her OK on the preview and an upload. Both are the asset lane and both
-- are daylight decisions. A parts build is the only one of the three that can be finished, reviewed
-- and merged in one night, and it is the one that puts a picture in front of her in the morning.
-- Every number it uses is in `Lobby.CONFIG`, so swapping the lodge for a mesh later changes this
-- module and nothing else.
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
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))

local Build = {}

-- WHAT THE LAST BUILD MADE. The module never prints: a tool that `require`s it over StudioMCP gets a
-- sandboxed copy with empty state (measured, task 122), so the owner prints and this answers.
local stats = { parts = 0, solids = 0, builds = 0 }

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

-- ---------------------------------------------------------------- the lodge

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
local function interior(folder: Instance, origin: Vector3, cfg)
	local size = cfg.LODGE.SIZE
	local inside = Instance.new("Folder")
	inside.Name = "Inside"
	inside.Parent = folder

	local backZ = origin.Z + size.Z / 2 - 2
	local stack = part(
		"Fireplace",
		Vector3.new(9, 13, 3),
		CFrame.new(origin.X - size.X / 4, origin.Y + 6.5, backZ),
		Color3.fromRGB(104, 104, 104),
		Enum.Material.Slate,
		true,
		inside
	)
	part(
		"Hearth",
		Vector3.new(9, 1, 4),
		CFrame.new(origin.X - size.X / 4, origin.Y + 0.5, backZ - 3),
		Color3.fromRGB(88, 88, 88),
		Enum.Material.Slate,
		false,
		inside
	)
	local fire = part(
		"Fire",
		Vector3.new(5, 2.5, 2),
		CFrame.new(origin.X - size.X / 4, origin.Y + 1.8, backZ - 2),
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
	local counterAt = Vector3.new(origin.X + size.X / 4, origin.Y + cfg.LODGE.COUNTER.Y / 2, backZ - 1)
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
		CFrame.new(counterAt.X, origin.Y + 7, backZ + 0.8),
		cfg.LODGE.SIGN_TEXT,
		shop
	)
end

local function lodge(container: Instance, anchor: Vector3, cfg): Instance
	local folder = Instance.new("Folder")
	folder.Name = "Lodge"
	local origin = anchor + cfg.LODGE.OFFSET
	local size = cfg.LODGE.SIZE
	local halfX, halfZ = size.X / 2, size.Z / 2

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

	interior(folder, Vector3.new(origin.X, origin.Y + 1, origin.Z), cfg)
	folder.Parent = container
	return folder
end

-- ---------------------------------------------------------------- the truck

local function truck(container: Instance, anchor: Vector3, cfg): Instance
	local folder = Instance.new("Folder")
	folder.Name = "Truck"
	local at = anchor + cfg.TRUCK.OFFSET
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

-- ---------------------------------------------------------------- the track and the yard

local function track(container: Instance, anchor: Vector3, cfg)
	local folder = Instance.new("Folder")
	folder.Name = "Track"
	local width = cfg.TRACK.WIDTH_STUDS
	local dirt = Color3.fromRGB(122, 102, 78)
	-- ONE STRIP RUNNING SOUTH out of the yard, past the truck, and one spur across the front of the
	-- lodge. Laid flush with the shelf, cosmetic, and never a thing a slug can stop in.
	part(
		"Lane",
		Vector3.new(width, 0.4, cfg.TRACK.TO_Z),
		CFrame.new(anchor.X + cfg.TRUCK.OFFSET.X, anchor.Y, anchor.Z + cfg.TRUCK.OFFSET.Z - cfg.TRACK.TO_Z / 2),
		dirt,
		cfg.TRACK.MATERIAL,
		false,
		folder
	)
	part(
		"Yard",
		Vector3.new(math.abs(cfg.TRUCK.OFFSET.X) + width, 0.4, width),
		CFrame.new(anchor.X + cfg.TRUCK.OFFSET.X / 2, anchor.Y, anchor.Z + cfg.SPOT.OFFSET.Z),
		dirt,
		cfg.TRACK.MATERIAL,
		false,
		folder
	)
	-- A woodpile and a trough: the two pieces of field dressing that say somebody lives here.
	for index = 1, 6 do
		local pile = part(
			string.format("Log%d", index),
			Vector3.new(7, 1.6, 1.6),
			CFrame.new(
				anchor.X - 24,
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

-- ---------------------------------------------------------------- the whole lobby

-- EVERY PART, BUILT ONCE, INTO ITS OWN FOLDER. `container` is an argument, so a spec builds the whole
-- thing into a Folder of its own and destroys it afterwards.
--
-- IDEMPOTENT: an existing folder of the same name is destroyed first, the `Body.OUTFIT_NAME`
-- discipline -- a second build must never leave two lodges standing.
--
-- Returns the folder, the `TruckSpot` part and how many parts it made, so the budget is a CHECKED
-- claim (`lobby.spec` asserts `<= CONFIG.MAX_PARTS`) and not a promise.
function Build.build(container: Instance, anchor: Vector3, cfg): (Instance, BasePart, BasePart, number)
	local existing = container:FindFirstChild(Data.FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	stats.parts = 0
	stats.solids = 0
	local folder = Instance.new("Folder")
	folder.Name = Data.FOLDER_NAME

	track(folder, anchor, cfg)
	lodge(folder, anchor, cfg)
	truck(folder, anchor, cfg)
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
