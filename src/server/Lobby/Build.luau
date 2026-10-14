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
-- SINCE TASK 186 A TRUCK IS SETTLED AND PAINTED AFTER IT IS BUILT, and both are measurements rather
-- than preferences. Karen: *"car tyers are inside earth"* -- every tyre of all four sat 0.752 studs
-- under the terrain and the east bay's worst wheel 2.017 under, because this module stood them on
-- the NOMINAL shelf and Roblox terrain is voxelised. `settleOnGround` rays under each WHEEL through
-- the world's own reader, exactly as `pad` does for its deck, and that is the same defect twice.
-- `camo` is her *"make cars comoflash like military like hunting cars"*: a repaint of the panels the
-- free model ships untextured, with the windows and the lamps left alone.
--
-- Design: docs/design/lobby.md (sections 9, 9.2, 12.2, 16.1 case 7)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md (section 4),
--         docs/research/2026-10-14-lobby-free-models.md (the free models, task 180),
--         docs/research/2026-10-14-trucks-on-the-ground.md (the settle and the camouflage, task 186)
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
	-- THE TRUCKS, ON THE GROUND AND IN CAMOUFLAGE (task 186). Karen: *"car tyers are inside earth"*
	-- and *"make cars comoflash like military like hunting cars"*.
	--
	-- `truckGroundStuds` IS THE WHOLE CLAIM AS A NUMBER: the worst wheel of the worst truck, in
	-- studs ABOVE the ground under it, after settling. The defect it replaces was 0.752 under for
	-- every wheel of three trucks and 2.017 under at the east bay, and a fix for that cannot be
	-- something anybody has to take on trust from a screenshot. `trucksSettled` says how many were
	-- measured at all, so a world with no ground reader is a counted state and not a silent one.
	trucksSettled = 0,
	truckGroundStuds = 0,
	truckPainted = 0,
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
--
-- OURS, FROM PARTS, AND THE FREE CABIN IS GONE (task 187). Karen, 2026-10-14 ~21:30, on the free
-- Creator Store cabins: *"all of then garbadge"*, and then: *"you build then one proper europen
-- standart"* -- a *"hunting house where will be fireplace table on walls animal antlers ect like
-- hunting cabin"*. Task 180's clone of "Log Cabin" (4746497269) is archived with its reason in
-- `backups/2026-10-14_task-187_free-lodge.txt` (rule 7): there is exactly ONE lodge now, so nothing
-- downstream has to ask which build it got and no measurement here is a guess about somebody else's
-- model.
--
-- WHAT A CENTRAL-EUROPEAN HUNTING LODGE IS MADE OF, and every piece below is one of these (the
-- research note, section 3, with the sources): a STONE PLINTH the logs never touch the earth
-- through; horizontally stacked LOGS whose ends PROJECT past the corner on alternating courses
-- ("corners with protruding beam ends, called projections" -- Freilichtmuseum Glentleiten, via
-- Google Arts & Culture); a steep GABLED roof with a deep overhang and exposed rafter ends; a stone
-- CHIMNEY up the gable end; small windows with frames, muntins and SHUTTERS; a covered PORCH with a
-- bench and a woodpile; antlers over the door.
--
-- THE SHAPE IS DATA. Every number is in `Lobby.CONFIG.LODGE`, which is what makes the doorway's gap,
-- the room's rectangle and the roof's pitch things a spec can assert rather than things a screenshot
-- has to be trusted about.
--
-- Note: docs/research/2026-10-14-european-hunting-lodge.md

-- THE ROOM INSIDE THE LODGE. Everything that hangs on a wall or stands on the floor is placed
-- against THIS and never against `cfg.LODGE.SIZE`, so a lodge that changes size moves its own
-- furniture.
export type Room = { centre: Vector3, halfX: number, halfZ: number, height: number }

-- WHERE THE WALKABLE FLOOR IS: the plinth's top plus the floorboards. One expression, called by
-- everything that needs it, because a floor height computed twice is a floor height that disagrees
-- with itself.
local function floorYOf(origin: Vector3, cfg): number
	return origin.Y + cfg.LODGE.PLINTH.HEIGHT + cfg.LODGE.FLOOR_THICK
end

-- HOW MANY LOG COURSES A WALL HAS, and therefore how tall it really is: a wall is a whole number of
-- logs, never the nominal height.
local function coursesOf(cfg): number
	return math.max(1, math.floor(cfg.LODGE.SIZE.Y / cfg.LODGE.LOG_DIAMETER))
end

-- PURE, AND EXPORTED, so `lobby.spec` can bound a trophy against the rectangle the mount actually
-- used instead of against the lodge's whole footprint (task 180 review round 1, finding 3: a
-- footprint bound is a stud and a half away from the wall and cannot see a plaque that has gone
-- through it).
--
-- THE INNER FACE OF A LOG WALL IS A WHOLE DIAMETER IN from the footprint, not half of one: the side
-- walls stand with their outer face on the footprint, so the room loses `LOG_DIAMETER` at each side.
function Build.roomFor(anchor: Vector3, cfg): Room
	local origin = anchor + cfg.LODGE.OFFSET
	local d = cfg.LODGE.LOG_DIAMETER
	return {
		centre = Vector3.new(origin.X, floorYOf(origin, cfg), origin.Z),
		halfX = cfg.LODGE.SIZE.X / 2 - d,
		halfZ = cfg.LODGE.SIZE.Z / 2 - d,
		height = coursesOf(cfg) * d,
	}
end

-- A HOLE IN A WALL: where along the wall, how wide, and between which two heights.
--
-- `along` IS IN THE WORLD AND NOT IN THE LODGE, and that sentence is here because the first build of
-- this wall got it wrong and nothing caught it: the config says a window is 11 studs east of the
-- lodge's middle, the wall runs from x 2833.8 to x 2866.2, and `11 +- 2.5` overlaps none of it -- so
-- every course was built whole and the house had no door and no windows at all. The spec did not see
-- it because its anchor is x = 0, where the two frames are the same thing. The door and every window
-- are the same thing to the wall builder, which is why there is one of it.
export type Opening = { along: number, width: number, bottom: number, top: number }

-- ONE WALL OF LOGS, WITH ITS HOLES CUT OUT. Karen asked for a door *"that you walk through"*, so a
-- door is the ABSENCE of parts and never a door panel -- and since task 187 a window is too, which
-- is what lets a frame, a sill and shutters sit in a real opening instead of being painted on a
-- blind wall.
--
-- Each course is split at the holes that are live at ITS height, so a wall with three openings at
-- three heights needs no special case and no second code path.
local function logWall(
	folder: Instance,
	name: string,
	axis: string,
	length: number,
	along: number, -- the wall's centre on its own axis
	across: number, -- the wall's position on the other axis
	baseY: number,
	cfg,
	openings: { Opening }
): number
	local d = cfg.LODGE.LOG_DIAMETER
	local placed = 0
	for course = 1, coursesOf(cfg) do
		local y = baseY + d / 2 + (course - 1) * d
		local cuts: { { number } } = {}
		for _, hole in ipairs(openings) do
			if y + d / 2 > hole.bottom and y - d / 2 < hole.top then
				table.insert(cuts, { hole.along - hole.width / 2, hole.along + hole.width / 2 })
			end
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local cursor = along - length / 2
		local runs: { { number } } = {}
		for _, cut in ipairs(cuts) do
			if cut[1] > cursor then
				table.insert(runs, { cursor, cut[1] })
			end
			cursor = math.max(cursor, cut[2])
		end
		if along + length / 2 > cursor then
			table.insert(runs, { cursor, along + length / 2 })
		end
		for index, run in ipairs(runs) do
			local span = run[2] - run[1]
			-- A SLIVER IS NOT A LOG: a run shorter than a log's own diameter is the gap a frame
			-- fills, and placing it would read as a splinter stuck to a window jamb.
			if span > d * 0.6 then
				local mid = (run[1] + run[2]) / 2
				local centre = if axis == "x" then Vector3.new(mid, y, across) else Vector3.new(across, y, mid)
				log(string.format("%s%d_%d", name, course, index), span, centre, axis, cfg, folder)
				placed += 1
			end
		end
	end
	return placed
end

-- THE CORNERS, AND THEY ARE THE WHOLE REASON THIS READS AS A LOG BUILDING AND NOT AS FOUR FENCES.
-- One stub per corner per course, turned a quarter turn every course, so the ends criss-cross the
-- way a notched corner does -- "corners with protruding beam ends, called projections ... the
-- projection cuts in logs are made around 15 to 20 cm from the end of the block" (Glentleiten).
-- `LOG_END_STUDS` is that projection.
--
-- It is also what CLOSES the corner: the two wall runs stop a diameter short of each other, and the
-- stub is the part that fills the square where they would have crossed.
local function corners(folder: Instance, origin: Vector3, baseY: number, cfg): number
	local d = cfg.LODGE.LOG_DIAMETER
	local out = cfg.LODGE.LOG_END_STUDS
	local halfX, halfZ = cfg.LODGE.SIZE.X / 2 - d / 2, cfg.LODGE.SIZE.Z / 2 - d / 2
	local placed = 0
	for course = 1, coursesOf(cfg) do
		local y = baseY + d / 2 + (course - 1) * d
		local axis = if course % 2 == 1 then "x" else "z"
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				log(
					string.format("WallEnd%d%s%s", course, if sx < 0 then "W" else "E", if sz < 0 then "S" else "N"),
					d + 2 * out,
					Vector3.new(origin.X + sx * halfX, y, origin.Z + sz * halfZ),
					axis,
					cfg,
					folder
				)
				placed += 1
			end
		end
	end
	return placed
end

-- ONE WINDOW, IN A HOLE THE WALL ALREADY LEFT: frame, glass, muntins, a sill and a pair of shutters
-- with the cut-out a Central-European shutter carries (a fir tree here; a heart is the other
-- classic). `face` sits on the wall plane with its LookVector pointing OUTWARD, so every offset
-- below is read in one direction and the same function hangs a window on any of the four walls.
--
-- THE GLASS IS SOLID AND THE REST IS NOT. A hole in a log wall that nothing closes is a hole a
-- player walks out of; the pane is what makes the window a window. It keeps `CanQuery`, because the
-- rule the rest of this file follows -- *a slab that stops a pellet changes what the shot hit* -- is
-- about DECORATION, and a wall is not decoration.
local function windowUnit(folder: Instance, name: string, face: CFrame, cfg)
	local spec = cfg.LODGE.WINDOW
	local w, h, f = spec.WIDTH, spec.HEIGHT, spec.FRAME
	local pane = part(
		string.format("WindowGlass%s", name),
		Vector3.new(w, h, 0.25),
		face,
		spec.GLASS_COLOR,
		Enum.Material.Glass,
		true,
		folder
	)
	pane.Transparency = spec.GLASS_TRANSPARENCY
	pane.Reflectance = 0.08
	for _, side in ipairs({ -1, 1 }) do
		part(
			string.format("WindowJamb%s%s", name, if side < 0 then "W" else "E"),
			Vector3.new(f, h + 2 * f, f * 2.2),
			face * CFrame.new(side * (w + f) / 2, 0, -0.1),
			spec.FRAME_COLOR,
			Enum.Material.WoodPlanks,
			false,
			folder
		)
	end
	part(
		string.format("WindowHead%s", name),
		Vector3.new(w + 2 * f, f, f * 2.2),
		face * CFrame.new(0, (h + f) / 2, -0.1),
		spec.FRAME_COLOR,
		Enum.Material.WoodPlanks,
		false,
		folder
	)
	-- THE SILL IS DEEPER THAN THE FRAME and proud of it on both sides: that shadow line under a
	-- window is most of what makes one read as built rather than drawn.
	part(
		string.format("WindowSill%s", name),
		Vector3.new(w + 2 * f + 1.2, f * 1.4, f * 3.4),
		face * CFrame.new(0, -(h + f * 1.4) / 2, -0.5),
		spec.SILL_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	part(
		string.format("WindowBar%sV", name),
		Vector3.new(0.3, h, 0.3),
		face * CFrame.new(0, 0, -0.2),
		spec.FRAME_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	part(
		string.format("WindowBar%sH", name),
		Vector3.new(w, 0.3, 0.3),
		face * CFrame.new(0, 0, -0.2),
		spec.FRAME_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	-- THE SHUTTERS, HELD OPEN AGAINST THE WALL, each turned out by `SHUTTER_OPEN_RADIANS` so they
	-- catch the light differently from the logs behind them.
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "W" else "E"
		local hinge = face
			* CFrame.new(side * (w / 2 + f), 0, -0.45)
			* CFrame.Angles(0, -side * spec.SHUTTER_OPEN_RADIANS, 0)
		local leaf = hinge * CFrame.new(side * w / 4, 0, 0)
		part(
			string.format("Shutter%s%s", name, tag),
			Vector3.new(w / 2, h, 0.35),
			leaf,
			spec.SHUTTER_COLOR,
			Enum.Material.WoodPlanks,
			false,
			folder
		)
		-- THE CUT-OUT. A Part cannot have a hole in it, so the shape is a darker piece laid ON the
		-- leaf -- which is what a painted shutter in the Alps looks like anyway.
		local tree = Instance.new("WedgePart")
		tree.Name = string.format("ShutterTree%s%s", name, tag)
		tree.Size = Vector3.new(0.18, 1.1, w / 2 - 0.9)
		tree.Anchored = true
		tree.CanCollide = false
		tree.CanQuery = false
		tree.CanTouch = false
		tree.CastShadow = false
		tree.Color = spec.CUTOUT_COLOR
		tree.Material = Enum.Material.SmoothPlastic
		tree.CFrame = leaf * CFrame.new(0, 0.35, -0.22) * CFrame.Angles(0, math.pi / 2, math.pi / 2)
		tree.Parent = folder
		stats.parts += 1
		part(
			string.format("ShutterTrunk%s%s", name, tag),
			Vector3.new(0.3, 0.55, 0.18),
			leaf * CFrame.new(0, -0.5, -0.22),
			spec.CUTOUT_COLOR,
			Enum.Material.SmoothPlastic,
			false,
			folder
		)
	end
end

-- THE DOORWAY'S FRAME: two squared jambs, a heavy lintel, a threshold board, and the leaf standing
-- OPEN against the wall. Nothing of it is ever IN the opening -- the spec asserts exactly that, and
-- it is the one thing about this building that could stop Karen getting into her own shop.
local function doorway(folder: Instance, origin: Vector3, floorY: number, cfg)
	local spec = cfg.LODGE.DOOR
	local halfZ = cfg.LODGE.SIZE.Z / 2
	local d = cfg.LODGE.LOG_DIAMETER
	local faceZ = origin.Z - halfZ + d / 2
	for _, side in ipairs({ -1, 1 }) do
		part(
			string.format("DoorPost%s", if side < 0 then "W" else "E"),
			Vector3.new(1.1, spec.HEIGHT + 0.8, d + 0.9),
			CFrame.new(origin.X + side * (spec.WIDTH + 1.1) / 2, floorY + (spec.HEIGHT + 0.8) / 2, faceZ),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			true,
			folder
		)
	end
	part(
		"DoorLintel",
		Vector3.new(spec.WIDTH + 3.4, 1.4, d + 1.4),
		CFrame.new(origin.X, floorY + spec.HEIGHT + 0.7, faceZ),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		true,
		folder
	)
	part(
		"DoorThreshold",
		Vector3.new(spec.WIDTH + 1.6, 0.3, d + 1.6),
		CFrame.new(origin.X, floorY + 0.15, faceZ),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	-- THE LEAF, OPEN, hinged on the east jamb and swung flat against the outside wall. Cosmetic, and
	-- it stands beside the opening rather than in it.
	local hinge = CFrame.new(origin.X + (spec.WIDTH + 1.1) / 2, floorY + spec.HEIGHT / 2, faceZ - d / 2 - 0.3)
		* CFrame.Angles(0, -spec.LEAF_OPEN_RADIANS, 0)
	local leaf = hinge * CFrame.new(spec.WIDTH / 2, 0, 0)
	part(
		"DoorLeaf",
		Vector3.new(spec.WIDTH, spec.HEIGHT - 0.4, 0.45),
		leaf,
		cfg.LODGE.DOOR_COLOR,
		Enum.Material.WoodPlanks,
		false,
		folder
	)
	for index, dy in ipairs({ -spec.HEIGHT / 4, spec.HEIGHT / 4 }) do
		part(
			string.format("DoorBand%d", index),
			Vector3.new(spec.WIDTH - 0.3, 0.4, 0.2),
			leaf * CFrame.new(0, dy, -0.3),
			Color3.fromRGB(42, 40, 38),
			Enum.Material.Metal,
			false,
			folder
		)
	end
end

-- THE ROOF: two slabs meeting at the ridge, a capping beam along it, the two gable triangles, and
-- the rafter ends that poke out under the eaves.
--
-- THE OVERHANG IS A TRANSLATION AND NOT A LONGER SLAB, which is the bug the old roof had: making
-- the slab longer grows it at BOTH ends, so the ridge end sails out past the peak and the two halves
-- cross in the air. Each slab is pushed DOWN ITS OWN SLOPE by half the overhang instead.
local function roof(folder: Instance, origin: Vector3, wallTop: number, cfg)
	local size = cfg.LODGE.SIZE
	local spec = cfg.LODGE.ROOF
	local ridge = origin.Y + cfg.LODGE.RIDGE_STUDS
	local rise = ridge - wallTop
	local halfZ = size.Z / 2
	local slope = math.sqrt(rise * rise + halfZ * halfZ)
	local pitch = math.atan2(rise, halfZ)
	local width = size.X + 2 * spec.GABLE_STUDS
	for _, side in ipairs({ -1, 1 }) do
		local down = Vector3.new(0, -rise / slope, side * halfZ / slope) * (spec.EAVE_STUDS / 2)
		part(
			if side < 0 then "RoofSouth" else "RoofNorth",
			Vector3.new(width, spec.THICK, slope + spec.EAVE_STUDS),
			CFrame.new(Vector3.new(origin.X, (wallTop + ridge) / 2, origin.Z + side * halfZ / 2) + down)
				* CFrame.Angles(side * pitch, 0, 0),
			spec.COLOR,
			spec.MATERIAL,
			true,
			folder
		)
		-- THE EXPOSED RAFTER ENDS. Cosmetic, under the eave, following the roof's own pitch.
		for index = 1, spec.RAFTERS do
			local t = (index - 0.5) / spec.RAFTERS
			part(
				string.format("Rafter%s%d", if side < 0 then "S" else "N", index),
				Vector3.new(0.55, 0.55, spec.EAVE_STUDS + 2.2),
				CFrame.new(
					origin.X - size.X / 2 + t * size.X,
					wallTop - math.tan(pitch) * (spec.EAVE_STUDS / 2) + 0.2,
					origin.Z + side * (halfZ + spec.EAVE_STUDS / 2)
				) * CFrame.Angles(side * pitch, 0, 0),
				cfg.LODGE.TIMBER_COLOR,
				Enum.Material.Wood,
				false,
				folder
			)
		end
	end
	part(
		"RoofRidge",
		Vector3.new(width + 0.6, 0.9, 1.8),
		CFrame.new(origin.X, ridge + 0.35, origin.Z),
		spec.RIDGE_COLOR,
		spec.MATERIAL,
		false,
		folder
	)
	-- THE TWO GABLE TRIANGLES, as boarded wedges: a WedgePart's slope runs along its own +Z, so one
	-- is turned to face the other.
	for _, side in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local wedge = Instance.new("WedgePart")
			wedge.Name = string.format("Gable%s%s", if side < 0 then "S" else "N", if half < 0 then "W" else "E")
			wedge.Size = Vector3.new(0.9, rise, halfZ)
			wedge.Anchored = true
			wedge.Color = spec.GABLE_COLOR
			wedge.Material = Enum.Material.WoodPlanks
			wedge.CanCollide = true
			wedge.CFrame = CFrame.new(
				origin.X + half * (size.X / 2 - 0.45),
				wallTop + rise / 2,
				origin.Z + side * halfZ / 2
			) * CFrame.Angles(0, if side < 0 then math.pi else 0, 0)
			wedge.Parent = folder
			stats.parts += 1
			stats.solids += 1
		end
	end
end

-- THE CHIMNEY, UP THE OUTSIDE OF THE WEST GABLE, which is where a Central-European lodge puts it and
-- is also why there is no hole to cut in the roof. It starts BELOW the ground so no eye ever finds
-- its bottom edge, and it finishes above the ridge, because a flue that stops short of the ridge
-- does not draw and -- more to the point here -- looks wrong.
local function chimney(folder: Instance, origin: Vector3, cfg)
	local spec = cfg.LODGE.CHIMNEY
	local top = origin.Y + cfg.LODGE.RIDGE_STUDS + spec.ABOVE_RIDGE_STUDS
	local base = origin.Y - 2
	local x = origin.X - cfg.LODGE.SIZE.X / 2 - spec.WIDTH / 2 + spec.INSET_STUDS
	local z = origin.Z + spec.ALONG_STUDS
	part(
		"ChimneyStack",
		Vector3.new(spec.WIDTH, top - base, spec.DEPTH),
		CFrame.new(x, (top + base) / 2, z),
		spec.COLOR,
		spec.MATERIAL,
		true,
		folder
	)
	part(
		"ChimneyCap",
		Vector3.new(spec.WIDTH + 1.2, 0.8, spec.DEPTH + 1.2),
		CFrame.new(x, top + 0.4, z),
		spec.CAP_COLOR,
		Enum.Material.Slate,
		false,
		folder
	)
	for index, dz in ipairs({ -spec.DEPTH / 4, spec.DEPTH / 4 }) do
		part(
			string.format("ChimneyPot%d", index),
			Vector3.new(1.1, 1.6, 1.1),
			CFrame.new(x, top + 1.6, z + dz),
			spec.CAP_COLOR,
			Enum.Material.Slate,
			false,
			folder
		)
	end
end

-- THE PORCH: where Karen arrives, and the one piece of this building a player touches before he can
-- see anything else. Deck, stone steps up to it, two posts with brackets, a lean-to roof, a bench, a
-- woodpile and two lanterns.
--
-- THE LEAN-TO HANGS OFF THE POINT THE MAIN EAVE ENDS, which is a measurement and not a preference.
-- Hung at the wall top -- where a porch roof "obviously" goes -- it was INSIDE the main roof: that
-- roof oversails the wall by `EAVE_STUDS` at 44 degrees, so its outer edge is already three studs
-- below the wall top and four studs south of the wall, and the whole porch roof sat above it,
-- invisible. The photograph is what said so.
local function porch(folder: Instance, origin: Vector3, floorY: number, wallTop: number, cfg)
	local spec = cfg.LODGE.PORCH
	local size = cfg.LODGE.SIZE
	local halfZ = size.Z / 2
	local deckZ = origin.Z - halfZ - spec.DEPTH / 2
	local width = size.X - spec.INSET_STUDS * 2
	local pitch = math.atan2(origin.Y + cfg.LODGE.RIDGE_STUDS - wallTop, halfZ)
	local eaveY = wallTop - math.tan(pitch) * cfg.LODGE.ROOF.EAVE_STUDS
	local eaveZ = origin.Z - halfZ - cfg.LODGE.ROOF.EAVE_STUDS
	-- THE STONE UNDER THE DECK, so the porch stands on something: a deck on posts alone shows
	-- daylight under it from every angle a player walks up at.
	part(
		"PorchBase",
		Vector3.new(width - 1.2, floorY - 0.6 - (origin.Y - 2), spec.DEPTH - 1.2),
		CFrame.new(origin.X, (floorY - 0.6 + origin.Y - 2) / 2, deckZ),
		cfg.LODGE.PLINTH.COLOR,
		cfg.LODGE.PLINTH.MATERIAL,
		true,
		folder
	)
	part(
		"Deck",
		Vector3.new(width, 0.6, spec.DEPTH),
		CFrame.new(origin.X, floorY - 0.3, deckZ),
		cfg.LODGE.DECK_COLOR,
		Enum.Material.WoodPlanks,
		true,
		folder
	)
	-- THE STEPS. Each rise is under a stud, so the engine walks a player up them without a jump --
	-- the floor is nearly three studs above the yard, which is more than a step.
	local stepTop = floorY - 0.6
	local ground = origin.Y - 0.4
	for index = 1, spec.STEPS do
		local rise = (stepTop - ground) / spec.STEPS
		part(
			string.format("PorchStep%d", index),
			Vector3.new(cfg.LODGE.DOOR.WIDTH + 5, rise, spec.STEP_DEPTH),
			CFrame.new(
				origin.X,
				ground + rise * (index - 0.5),
				deckZ - spec.DEPTH / 2 - spec.STEP_DEPTH * (spec.STEPS - index + 0.5)
			),
			cfg.LODGE.PLINTH.COLOR,
			cfg.LODGE.PLINTH.MATERIAL,
			true,
			folder
		)
	end
	-- THE POSTS AND THEIR BRACKETS, and the brackets are the detail that stops a post reading as a
	-- pipe: a carved knee under every plate, which every timber porch in the Alps has.
	local postTop = floorY + spec.POST_STUDS
	local plateZ = deckZ - spec.DEPTH / 2 + 1.2
	for _, sx in ipairs({ -1, 1 }) do
		local x = origin.X + sx * (width / 2 - 1.2)
		part(
			string.format("PorchPost%s", if sx < 0 then "W" else "E"),
			Vector3.new(1.3, postTop - floorY, 1.3),
			CFrame.new(x, (postTop + floorY) / 2, plateZ),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			true,
			folder
		)
		for _, sz in ipairs({ -1, 1 }) do
			local knee = Instance.new("WedgePart")
			knee.Name = string.format("PorchKnee%s%s", if sx < 0 then "W" else "E", if sz < 0 then "S" else "N")
			-- SMALL. At 1.8 studs they read as arrowheads stuck to the posts, which the first
			-- photograph showed and nothing else would have.
			knee.Size = Vector3.new(0.5, 1.1, 1.1)
			knee.Anchored = true
			knee.CanCollide = false
			knee.CanQuery = false
			knee.CanTouch = false
			knee.Color = cfg.LODGE.TIMBER_COLOR
			knee.Material = Enum.Material.Wood
			knee.CFrame = CFrame.new(x, postTop - 1.0, plateZ + sz * 1.0)
				* CFrame.Angles(0, if sz < 0 then 0 else math.pi, 0)
			knee.Parent = folder
			stats.parts += 1
		end
	end
	part(
		"PorchPlate",
		Vector3.new(width + 1.4, 0.9, 1.1),
		CFrame.new(origin.X, postTop + 0.45, plateZ),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		true,
		folder
	)
	-- THE PORCH ROOF, a shallow lean-to from under the main eave out over the deck. Its two ends are
	-- the two things it has to meet: the main roof's outer edge, and the plate on the posts.
	local frontZ = plateZ - spec.OVERHANG_STUDS
	local run = eaveZ - frontZ
	local drop = eaveY - 0.4 - (postTop + 0.9)
	part(
		"PorchRoof",
		Vector3.new(width + 3.2, 0.7, math.sqrt(run * run + drop * drop) + 0.8),
		CFrame.new(origin.X, (eaveY - 0.4 + postTop + 0.9) / 2, (eaveZ + frontZ) / 2)
			* CFrame.Angles(-math.atan2(drop, run), 0, 0),
		cfg.LODGE.ROOF.COLOR,
		cfg.LODGE.ROOF.MATERIAL,
		true,
		folder
	)
	-- THE BENCH beside the door, on the west side.
	local benchX = origin.X - cfg.LODGE.DOOR.WIDTH / 2 - 4.4
	part(
		"PorchBench",
		Vector3.new(5.4, 0.45, 1.8),
		CFrame.new(benchX, floorY + 1.5, deckZ + spec.DEPTH / 4),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.WoodPlanks,
		true,
		folder
	)
	for index, dx in ipairs({ -2.2, 2.2 }) do
		part(
			string.format("PorchBenchLeg%d", index),
			Vector3.new(0.6, 1.5, 1.6),
			CFrame.new(benchX + dx, floorY + 0.75, deckZ + spec.DEPTH / 4),
			cfg.LODGE.FURNITURE_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
	end
	-- THE WOODPILE on the east side. Stacked split logs: rows of cylinders, every other row offset,
	-- which is the whole trick to making a stack read as a stack.
	local pileX = origin.X + cfg.LODGE.DOOR.WIDTH / 2 + 5.4
	for row = 1, spec.WOOD_ROWS do
		for index = 1, spec.WOOD_PER_ROW do
			local offset = if row % 2 == 0 then 0.55 else 0
			local piece = part(
				string.format("Firewood%d_%d", row, index),
				Vector3.new(spec.DEPTH - 2.6, 1.05, 1.05),
				CFrame.new(
					pileX - spec.WOOD_PER_ROW * 0.55 + (index - 0.5) * 1.1 + offset,
					floorY + 0.55 + (row - 1) * 0.95,
					deckZ + spec.DEPTH / 5
				) * CFrame.Angles(0, math.pi / 2, 0),
				if (row + index) % 3 == 0 then cfg.LODGE.LOG_COLOR else cfg.LODGE.FIREWOOD_COLOR,
				Enum.Material.Wood,
				false,
				folder
			)
			piece.Shape = Enum.PartType.Cylinder
		end
	end
	-- TWO LANTERNS, one each side of the door, and they are the only lights outside.
	for _, sx in ipairs({ -1, 1 }) do
		local tag = if sx < 0 then "W" else "E"
		local x = origin.X + sx * (cfg.LODGE.DOOR.WIDTH / 2 + 2.1)
		local box = part(
			string.format("PorchLantern%s", tag),
			Vector3.new(0.9, 1.3, 0.9),
			CFrame.new(x, floorY + cfg.LODGE.DOOR.HEIGHT - 1.4, origin.Z - halfZ - 0.9),
			cfg.LODGE.LANTERN.GLASS_COLOR,
			Enum.Material.Neon,
			false,
			folder
		)
		box.Transparency = 0.25
		part(
			string.format("PorchLanternCap%s", tag),
			Vector3.new(1.2, 0.35, 1.2),
			CFrame.new(x, floorY + cfg.LODGE.DOOR.HEIGHT - 0.6, origin.Z - halfZ - 0.9),
			Color3.fromRGB(38, 36, 34),
			Enum.Material.Metal,
			false,
			folder
		)
		local lamp = Instance.new("PointLight")
		lamp.Name = "LanternLight"
		lamp.Brightness = cfg.LODGE.LANTERN.brightness
		lamp.Range = cfg.LODGE.LANTERN.rangeStuds
		lamp.Color = cfg.LODGE.LANTERN.color
		lamp.Shadows = false
		lamp.Parent = box
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

	-- HIS FACE, AND IT IS THE "person inside broken" KAREN REPORTED (2026-10-14 ~17:00). The outfit
	-- owner paints the five R6 limb stems and NEVER `HeadColor3` -- "the head is the player's own"
	-- (`Body.paint`, design M5) -- which is right for a player and leaves this man with the head an
	-- EMPTY `HumanoidDescription` ships: solid black, and no face on it. He is not a player and has
	-- no appearance of his own, so the lodge gives him one: a skin tone on every `BodyColors` the
	-- character carries (`Body.paint`'s own all-of-them rule, for its stated reason) and Roblox's
	-- built-in face texture, which is an engine asset and not an upload.
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("BodyColors") then
			(child :: any).HeadColor3 = keep.SKIN_COLOR
		end
	end
	local face = body:FindFirstChild("Head")
	if face ~= nil and (face :: Instance):IsA("BasePart") then
		(face :: BasePart).Color = keep.SKIN_COLOR
		local look = Instance.new("Decal")
		look.Name = "face"
		look.Face = Enum.NormalId.Front
		look.Texture = keep.FACE_TEXTURE
		look.Parent = face
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

-- ---------------------------------------------------------------- the trophies (task 187)

-- ONE TAPERED LENGTH OF ANTLER, laid from `from` along `dir` in the MOUNT'S OWN FRAME, and it
-- answers where it ended so the next one starts there. A Part cannot taper, so a beam is a chain of
-- cylinders that each lose a fifth of the last one's thickness -- which is what makes a row of these
-- read as antlers at ten studs instead of as a bundle of sticks.
--
-- A cylinder's own length is its X, so the frame is turned a quarter turn after it is aimed: the
-- same correction `post`, `Horn.pieces` and `Markers.ring` all make.
local function antlerPiece(
	folder: Instance,
	name: string,
	face: CFrame,
	from: Vector3,
	dir: Vector3,
	length: number,
	thick: number,
	colour: Color3
): Vector3
	local unit = dir.Unit
	local mid = from + unit * (length / 2)
	local piece = part(
		name,
		Vector3.new(length, thick, thick),
		face * CFrame.lookAt(mid, mid + unit, Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.pi / 2, 0),
		colour,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	piece.Shape = Enum.PartType.Cylinder
	return from + unit * length
end

-- ONE BEAM AND ITS TINES. The beam leaves the skull leaning outward and straightens as it rises,
-- which is the shape of a roe buck's; the tines come off the joints, forward and up.
local function antlerBeam(folder: Instance, name: string, face: CFrame, root: Vector3, side: number, spec, bone: Color3)
	local at = root
	local thick = spec.THICK
	local dir = Vector3.new(side * spec.SPREAD, 1, -0.14)
	for index = 1, spec.SEGMENTS do
		at = antlerPiece(folder, string.format("%sB%d", name, index), face, at, dir, spec.SEGMENT_STUDS, thick, bone)
		thick *= 0.82
		dir = Vector3.new(dir.X + side * spec.CURVE, dir.Y, dir.Z - 0.06)
		if index <= spec.TINES then
			antlerPiece(
				folder,
				string.format("%sT%d", name, index),
				face,
				at,
				Vector3.new(side * 0.18, 1, -0.55),
				spec.TINE_STUDS,
				thick * 0.78,
				bone
			)
		end
	end
end

-- THE SHIELD EVERY TROPHY HANGS ON: a Central-European `Trophaeenschild` is a small dark wooden
-- shield, taller than it is wide, with the skull plate screwed to the middle of it -- "plaque length
-- of 22 cm, width of 10 cm, antler length of 10.5 cm" on the measured example in the note, which is
-- the 2.2 : 1 proportion used here and the reason the antlers are about half the plaque's height.
--
-- `face` lies on the WALL with its LookVector pointing INTO the room, so `-Z` is "out from the
-- wall" for everything below.
local function shield(folder: Instance, name: string, face: CFrame, size: Vector3, cfg): CFrame
	part(
		string.format("%sPlaque", name),
		size,
		face * CFrame.new(0, 0, -size.Z / 2),
		cfg.TROPHIES.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	-- THE POINT AT THE BOTTOM, which is what makes a rectangle a shield.
	local point = Instance.new("WedgePart")
	point.Name = string.format("%sPoint", name)
	point.Size = Vector3.new(size.Z, size.X * 0.42, size.X)
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.CastShadow = false
	point.Color = cfg.TROPHIES.PLAQUE_COLOR
	point.Material = Enum.Material.Wood
	point.CFrame = face
		* CFrame.new(0, -size.Y / 2 - size.X * 0.21, -size.Z / 2)
		* CFrame.Angles(0, math.pi / 2, math.pi / 2)
	point.Parent = folder
	stats.parts += 1
	return face * CFrame.new(0, 0, -size.Z)
end

-- A ROE OR RED-DEER MOUNT: the shield, the skull plate, two beams.
local function antlerMount(folder: Instance, name: string, face: CFrame, spec, cfg)
	local front = shield(folder, name, face, spec.PLAQUE, cfg)
	local bone = cfg.TROPHIES.BONE_COLOR
	local skull = part(
		string.format("%sSkull", name),
		Vector3.new(spec.PLAQUE.X * 0.42, spec.PLAQUE.Y * 0.3, spec.PLAQUE.Z * 1.1),
		front * CFrame.new(0, spec.PLAQUE.Y * 0.14, -spec.PLAQUE.Z * 0.55),
		bone,
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	skull.Name = skull.Name
	local root = Vector3.new(0, spec.PLAQUE.Y * 0.26, -spec.PLAQUE.Z * 0.6)
	for _, side in ipairs({ -1, 1 }) do
		antlerBeam(
			folder,
			string.format("%s%s", name, if side < 0 then "W" else "E"),
			front,
			root + Vector3.new(side * spec.PLAQUE.X * 0.1, 0, 0),
			side,
			spec,
			bone
		)
	end
end

-- A BOAR'S TUSK MOUNT: the shield, the lower jaw plate, and the two tusks curling up and out. Karen
-- asked for *"head of boar"* in task 180 and this is the lodge-wall version of it -- the classic
-- `Gewaff` plate, which is what hangs on a European wall between the antlers.
local function boarMount(folder: Instance, name: string, face: CFrame, spec, cfg)
	local front = shield(folder, name, face, spec.PLAQUE, cfg)
	local bone = cfg.TROPHIES.BONE_COLOR
	part(
		string.format("%sJaw", name),
		Vector3.new(spec.PLAQUE.X * 0.55, spec.PLAQUE.Y * 0.26, spec.PLAQUE.Z * 1.4),
		front * CFrame.new(0, 0, -spec.PLAQUE.Z * 0.7),
		Color3.fromRGB(212, 202, 180),
		Enum.Material.SmoothPlastic,
		false,
		folder
	)
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "W" else "E"
		local at = Vector3.new(side * spec.PLAQUE.X * 0.16, -spec.PLAQUE.Y * 0.06, -spec.PLAQUE.Z * 0.8)
		at = antlerPiece(
			folder,
			string.format("%sTusk%sA", name, tag),
			front,
			at,
			Vector3.new(side * 0.5, 1, -0.2),
			spec.TUSK_STUDS,
			spec.THICK,
			bone
		)
		antlerPiece(
			folder,
			string.format("%sTusk%sB", name, tag),
			front,
			at,
			Vector3.new(side * 1, 0.35, -0.15),
			spec.TUSK_STUDS * 0.8,
			spec.THICK * 0.75,
			bone
		)
	end
end

-- THE TROPHY WALL. Karen, 2026-10-14: *"on walls animal antlers ect"*, and task 180's *"trophys like
-- head of deer head of boar"*.
--
-- A MOUNT NAMES A WALL, how far along it, how high, and how far the wall's face is from the
-- footprint -- the last of those is what lets the red stag hang on the CHIMNEY BREAST, which stands
-- three studs proud of the wall behind it, instead of three studs inside the stonework.
--
-- `yaw` IS THE DIRECTION THE MOUNT LOOKS. A CFrame's LookVector is its own -Z, so
-- `CFrame.Angles(0, 0, 0)` looks at -Z (the north wall, looking south) -- getting that backwards
-- does not fail, it hangs the whole set on the OUTSIDE of the lodge, which is exactly what the first
-- inside shot of task 180 showed.
--
-- IT IS MEASURED AFTER IT IS BUILT AND MOVED IF IT DOES NOT FIT, which is the only honest way to do
-- this: a mount is a dozen cylinders aimed along a curve, and no arithmetic over `SEGMENTS` and
-- `SPREAD` says where the top tine really ended. Each mount goes in a Folder of its own, its true
-- vertical span is read off the parts (the Y extent of a rotated box, not `Position.Y +- Size.Y /
-- 2`, which is wrong for every cylinder here), and the whole folder is shifted until it is inside
-- the room. Task 180 shipped the guessed version and hung a deer through the ceiling.
local function spanY(piece: BasePart): (number, number)
	local _, _, _, _, _, _, m10, m11, m12 = piece.CFrame:GetComponents()
	local half = 0.5 * (math.abs(m10) * piece.Size.X + math.abs(m11) * piece.Size.Y + math.abs(m12) * piece.Size.Z)
	return piece.Position.Y - half, piece.Position.Y + half
end

local function trophies(inside: Instance, room: Room, cfg)
	local folder = Instance.new("Folder")
	folder.Name = "Trophies"
	folder.Parent = inside
	local spec = cfg.TROPHIES
	for index, mount in ipairs(spec.MOUNTS) do
		local standoff = mount.standoff or 0
		local at, yaw
		if mount.wall == "north" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z + room.halfZ - standoff), 0
		elseif mount.wall == "south" then
			at, yaw = Vector3.new(room.centre.X + mount.along, 0, room.centre.Z - room.halfZ + standoff), math.pi
		elseif mount.wall == "west" then
			at, yaw = Vector3.new(room.centre.X - room.halfX + standoff, 0, room.centre.Z + mount.along), -math.pi / 2
		else
			at, yaw = Vector3.new(room.centre.X + room.halfX - standoff, 0, room.centre.Z + mount.along), math.pi / 2
		end
		local kind = spec[string.upper(mount.kind)]
		local one = Instance.new("Folder")
		one.Name = string.format("Mount%d", index)
		one.Parent = folder
		local wanted = room.centre.Y + (mount.height or spec.HEIGHT_STUDS)
		local name = string.format("%s%d", mount.kind, index)
		local face = CFrame.new(Vector3.new(at.X, wanted, at.Z)) * CFrame.Angles(0, yaw, 0)
		if mount.kind == "boar" then
			boarMount(one, name, face, kind, cfg)
		else
			antlerMount(one, name, face, kind, cfg)
		end
		local lowest, highest = math.huge, -math.huge
		for _, piece in ipairs(one:GetChildren()) do
			if piece:IsA("BasePart") then
				local bottom, top = spanY(piece :: BasePart)
				lowest, highest = math.min(lowest, bottom), math.max(highest, top)
			end
		end
		-- DOWN FROM THE BOARDS FIRST, THEN UP OFF THE FLOOR: a mount taller than the room would
		-- fight itself, and in that order it ends resting on the floor rather than through the
		-- ceiling, which is the better of the two wrong answers.
		local shift = math.min(0, room.centre.Y + room.height - 0.3 - highest)
		shift += math.max(0, room.centre.Y + 0.3 - (lowest + shift))
		if math.abs(shift) > 1e-4 then
			for _, piece in ipairs(one:GetChildren()) do
				if piece:IsA("BasePart") then
					local moved = piece :: BasePart
					moved.CFrame = moved.CFrame + Vector3.new(0, shift, 0)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- the warm inside

-- THE FIREPLACE, AND IT IS THE FIRST THING KAREN ASKED FOR: *"hunting house where will be
-- fireplace"*. A stone breast standing proud of the west wall, two piers, a heavy timber mantel, a
-- sooty back, a stone hearth on the floorboards, three logs, and ONE light.
--
-- THE FIRE IS A `Fire` PLUS A `ParticleEmitter` PLUS A `PointLight`, which is Roblox's own way of
-- doing it -- `Fire` carries the flame and the heat haze, the emitter throws the embers the flame
-- does not, and the light is what actually makes the room warm. Nothing here is written per frame:
-- the flicker is the engine's.
--   Fire             https://create.roblox.com/docs/reference/engine/classes/Fire
--   ParticleEmitter  https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter
--   PointLight       https://create.roblox.com/docs/reference/engine/classes/PointLight
local function fireplace(inside: Instance, room: Room, cfg)
	local spec = cfg.LODGE.FIREPLACE
	local floorY = room.centre.Y
	local wallX = room.centre.X - room.halfX
	local z = room.centre.Z + spec.ALONG_STUDS
	local breastX = wallX + spec.DEPTH / 2
	-- THE BREAST, from the mantel up to the boards: the chimney's inside face.
	part(
		"FireplaceBreast",
		Vector3.new(spec.DEPTH, room.height - spec.OPENING_HEIGHT - 1.2, spec.WIDTH),
		CFrame.new(breastX, floorY + spec.OPENING_HEIGHT + 1.2 + (room.height - spec.OPENING_HEIGHT - 1.2) / 2, z),
		spec.STONE_COLOR,
		Enum.Material.Cobblestone,
		true,
		inside
	)
	for _, side in ipairs({ -1, 1 }) do
		part(
			string.format("FireplacePier%s", if side < 0 then "S" else "N"),
			Vector3.new(spec.DEPTH, spec.OPENING_HEIGHT + 1.2, (spec.WIDTH - spec.OPENING_WIDTH) / 2),
			CFrame.new(
				breastX,
				floorY + (spec.OPENING_HEIGHT + 1.2) / 2,
				z + side * (spec.WIDTH + spec.OPENING_WIDTH) / 4
			),
			spec.STONE_COLOR,
			Enum.Material.Cobblestone,
			true,
			inside
		)
	end
	part(
		"FireplaceBack",
		Vector3.new(0.9, spec.OPENING_HEIGHT, spec.OPENING_WIDTH),
		CFrame.new(wallX + 0.45, floorY + spec.OPENING_HEIGHT / 2, z),
		Color3.fromRGB(38, 34, 32),
		Enum.Material.Slate,
		false,
		inside
	)
	-- THE MANTEL: one squared beam across the opening, and the thing a stag's head hangs over.
	part(
		"FireplaceMantel",
		Vector3.new(spec.DEPTH + 0.8, 1.1, spec.WIDTH + 1),
		CFrame.new(breastX + 0.4, floorY + spec.OPENING_HEIGHT + 0.6, z),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	part(
		"FireplaceHearth",
		Vector3.new(spec.DEPTH + spec.HEARTH_STUDS, 0.35, spec.WIDTH + 1.6),
		CFrame.new(breastX + spec.HEARTH_STUDS / 2, floorY + 0.18, z),
		spec.HEARTH_COLOR,
		Enum.Material.Slate,
		false,
		inside
	)
	-- THE LOGS, AND THEN THE FIRE ON THEM.
	for index, dz in ipairs({ -0.8, 0, 0.8 }) do
		local billet = part(
			string.format("FireLog%d", index),
			Vector3.new(spec.OPENING_WIDTH - 1.4, 0.75, 0.75),
			CFrame.new(breastX + 0.3, floorY + 0.5 + (if index == 2 then 0.6 else 0), z + dz)
				* CFrame.Angles(0, math.pi / 2, 0)
				* CFrame.Angles(0, 0, if index == 2 then 0.12 else 0),
			cfg.LODGE.FIREWOOD_COLOR,
			Enum.Material.Wood,
			false,
			inside
		)
		billet.Shape = Enum.PartType.Cylinder
	end
	-- THE EMITTER PART IS SMALL AND MOSTLY TRANSPARENT. The first build made it the width of the
	-- firebox at 0.45 transparency, and with a `Fire` of size 7 on top of it the photograph came back
	-- with a white blob where the hearth is: what you see of a fire is the FLAME, not the box it is
	-- attached to.
	local fire = part(
		"Fire",
		Vector3.new(spec.OPENING_WIDTH - 3, 0.8, 1.2),
		CFrame.new(breastX + 0.3, floorY + 1, z),
		Color3.fromRGB(255, 142, 48),
		Enum.Material.Neon,
		false,
		inside
	)
	fire.Transparency = 0.7
	local flame = Instance.new("Fire")
	flame.Name = "Flame"
	flame.Size = cfg.LODGE.FIRE.SIZE
	flame.Heat = cfg.LODGE.FIRE.HEAT
	flame.Color = cfg.LODGE.FIRE.COLOR
	flame.SecondaryColor = cfg.LODGE.FIRE.SECONDARY_COLOR
	flame.Parent = fire
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Rate = cfg.LODGE.FIRE.EMBER_RATE
	embers.Lifetime = NumberRange.new(0.8, 1.8)
	embers.Speed = NumberRange.new(1.5, 3.5)
	embers.Size = NumberSequence.new(0.14)
	embers.Transparency = NumberSequence.new(0.25)
	embers.Color = ColorSequence.new(cfg.LODGE.FIRE.COLOR, cfg.LODGE.FIRE.SECONDARY_COLOR)
	embers.SpreadAngle = Vector2.new(14, 14)
	embers.Acceleration = Vector3.new(0, 4, 0)
	embers.LightEmission = 1
	embers.Parent = fire
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Brightness = cfg.LODGE.FIRE_LIGHT.brightness
	light.Range = cfg.LODGE.FIRE_LIGHT.rangeStuds
	light.Color = cfg.LODGE.FIRE_LIGHT.color
	light.Shadows = false
	light.Parent = fire
end

-- A HANGING LANTERN: the glass, the cap, the chain up to the beam, and a small warm light. Three of
-- them plus the fire is what *"warm inside"* actually comes to.
local function lantern(inside: Instance, name: string, at: Vector3, ceilingY: number, cfg)
	local box = part(
		name,
		Vector3.new(0.85, 1.2, 0.85),
		CFrame.new(at),
		cfg.LODGE.LANTERN.GLASS_COLOR,
		Enum.Material.Neon,
		false,
		inside
	)
	box.Transparency = 0.25
	part(
		string.format("%sCap", name),
		Vector3.new(1.15, 0.3, 1.15),
		CFrame.new(at + Vector3.new(0, 0.75, 0)),
		Color3.fromRGB(38, 36, 34),
		Enum.Material.Metal,
		false,
		inside
	)
	local chain = part(
		string.format("%sChain", name),
		Vector3.new(ceilingY - at.Y - 0.75, 0.14, 0.14),
		CFrame.new(at + Vector3.new(0, (ceilingY - at.Y + 0.75) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(38, 36, 34),
		Enum.Material.Metal,
		false,
		inside
	)
	chain.Shape = Enum.PartType.Cylinder
	local lamp = Instance.new("PointLight")
	lamp.Name = "LanternLight"
	lamp.Brightness = cfg.LODGE.LANTERN.brightness
	lamp.Range = cfg.LODGE.LANTERN.rangeStuds
	lamp.Color = cfg.LODGE.LANTERN.color
	lamp.Shadows = false
	lamp.Parent = box
end

-- THE WARM INSIDE: floorboards, a beamed ceiling, the fireplace, a heavy table with its benches,
-- three lanterns, a gun rack, the shop counter -- and, since task 181, the man standing behind it.
-- Nothing here is animated per frame and nothing is written per frame: the keeper's idle is played
-- once, at build, and his head is turned by the owner's own 10 Hz scan.
local function interior(folder: Instance, room: Room, cfg, seams: Seams?)
	local origin = room.centre
	local inside = Instance.new("Folder")
	inside.Name = "Inside"
	inside.Parent = folder
	local ceilingY = origin.Y + room.height

	-- THE BEAMED CEILING. Boards first, then the beams under them, which is the order they are built
	-- in and the order they read in.
	part(
		"CeilingBoards",
		Vector3.new(room.halfX * 2, 0.4, room.halfZ * 2),
		CFrame.new(origin.X, ceilingY - 0.2, origin.Z),
		cfg.LODGE.CEILING_COLOR,
		Enum.Material.WoodPlanks,
		false,
		inside
	)
	for index = 1, cfg.LODGE.CEILING_BEAMS do
		local t = (index - 0.5) / cfg.LODGE.CEILING_BEAMS
		part(
			string.format("CeilingBeam%d", index),
			Vector3.new(1, 0.9, room.halfZ * 2),
			CFrame.new(origin.X - room.halfX + t * room.halfX * 2, ceilingY - 0.85, origin.Z),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			inside
		)
	end

	fireplace(inside, room, cfg)

	-- THE TABLE AND ITS BENCHES, in the middle of the room where a hunting party eats.
	local spec = cfg.LODGE.TABLE
	local tableX, tableZ = origin.X + spec.OFFSET.X, origin.Z + spec.OFFSET.Y
	part(
		"TableTop",
		Vector3.new(spec.SIZE.X, 0.55, spec.SIZE.Y),
		CFrame.new(tableX, origin.Y + spec.HEIGHT, tableZ),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.WoodPlanks,
		true,
		inside
	)
	for index, dx in ipairs({ -spec.SIZE.X / 2 + 1.1, spec.SIZE.X / 2 - 1.1 }) do
		part(
			string.format("TableLeg%d", index),
			Vector3.new(0.9, spec.HEIGHT - 0.3, spec.SIZE.Y - 0.8),
			CFrame.new(tableX + dx, origin.Y + (spec.HEIGHT - 0.3) / 2, tableZ),
			cfg.LODGE.FURNITURE_COLOR,
			Enum.Material.Wood,
			true,
			inside
		)
	end
	part(
		"TableRail",
		Vector3.new(spec.SIZE.X - 2.6, 0.5, 0.6),
		CFrame.new(tableX, origin.Y + spec.HEIGHT - 1.4, tableZ),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	for index, dz in ipairs({ -spec.BENCH_STUDS, spec.BENCH_STUDS }) do
		part(
			string.format("Bench%d", index),
			Vector3.new(spec.SIZE.X - 1.4, 0.45, 1.9),
			CFrame.new(tableX, origin.Y + spec.BENCH_HEIGHT, tableZ + dz),
			cfg.LODGE.FURNITURE_COLOR,
			Enum.Material.WoodPlanks,
			true,
			inside
		)
		for leg, dx in ipairs({ -spec.SIZE.X / 2 + 1.4, spec.SIZE.X / 2 - 1.4 }) do
			part(
				string.format("BenchLeg%d_%d", index, leg),
				Vector3.new(0.6, spec.BENCH_HEIGHT - 0.2, 1.7),
				CFrame.new(tableX + dx, origin.Y + (spec.BENCH_HEIGHT - 0.2) / 2, tableZ + dz),
				cfg.LODGE.FURNITURE_COLOR,
				Enum.Material.Wood,
				false,
				inside
			)
		end
	end

	-- THE GUN RACK on the west wall, south of the fireplace: a board, its pegs, and two long guns.
	-- It is scenery and holds nothing -- `Weapon.Hardware` is the only thing in this game that builds
	-- a gun a player can touch. `face` looks INTO the room, the same convention every trophy uses.
	local rack = cfg.LODGE.RACK
	local face = CFrame.new(origin.X - room.halfX, origin.Y + rack.HEIGHT_STUDS, origin.Z + rack.ALONG_STUDS)
		* CFrame.Angles(0, -math.pi / 2, 0)
	part(
		"GunRackBoard",
		Vector3.new(rack.WIDTH, 3.6, 0.4),
		face * CFrame.new(0, 0, -0.2),
		cfg.TROPHIES.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	for index = 1, 3 do
		local along = -rack.WIDTH / 2 + index * rack.WIDTH / 4
		for peg, dy in ipairs({ -1.2, 1.2 }) do
			local hook = part(
				string.format("GunRackPeg%d_%d", index, peg),
				Vector3.new(0.9, 0.3, 0.3),
				face * CFrame.new(along, dy, -0.9) * CFrame.Angles(0, math.pi / 2, 0),
				cfg.LODGE.TIMBER_COLOR,
				Enum.Material.Wood,
				false,
				inside
			)
			hook.Shape = Enum.PartType.Cylinder
		end
		if index < 3 then
			part(
				string.format("GunRackBarrel%d", index),
				Vector3.new(0.35, 4.6, 0.35),
				face * CFrame.new(along + 0.4, 0.6, -1.1) * CFrame.Angles(0, 0, 0.06),
				Color3.fromRGB(46, 46, 48),
				Enum.Material.Metal,
				false,
				inside
			)
			part(
				string.format("GunRackStock%d", index),
				Vector3.new(0.7, 2.1, 0.5),
				face * CFrame.new(along + 0.4, -2.1, -1.1),
				Color3.fromRGB(96, 62, 38),
				Enum.Material.Wood,
				false,
				inside
			)
		end
	end

	-- THREE LANTERNS, hung off the beams.
	for index, dx in ipairs(cfg.LODGE.LANTERN.ALONG) do
		lantern(
			inside,
			string.format("Lantern%d", index),
			Vector3.new(origin.X + dx, ceilingY - cfg.LODGE.LANTERN.DROP_STUDS, origin.Z + cfg.LODGE.LANTERN.ACROSS),
			ceilingY,
			cfg
		)
	end

	-- THE SHOP (task 177 built it empty, task 178 opened it): the counter is the DOOR, found by name
	-- through `Lobby.counterPart` and measured against by the server's own reach check. Karen:
	-- *"Hunting house where inside can shop things"*.
	local shop = Instance.new("Folder")
	shop.Name = "Shop"
	shop.Parent = inside
	-- CLAMPED SO IT CANNOT COME THROUGH THE WALL: the counter's east end has to stay inside the room
	-- whatever the room is, which is the clamp task 180's review asked for and this keeps.
	local counterX = math.min(cfg.LODGE.COUNTER_ALONG, math.max(0, room.halfX - cfg.LODGE.COUNTER.X / 2 - 0.6))
	local counterAt = Vector3.new(
		origin.X + counterX,
		origin.Y + cfg.LODGE.COUNTER.Y / 2,
		origin.Z + room.halfZ - cfg.LODGE.COUNTER_BACK
	)
	part(
		"Counter",
		cfg.LODGE.COUNTER,
		CFrame.new(counterAt),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.WoodPlanks,
		true,
		shop
	)
	part(
		"CounterTop",
		Vector3.new(cfg.LODGE.COUNTER.X + 0.8, 0.35, cfg.LODGE.COUNTER.Z + 0.8),
		CFrame.new(counterAt + Vector3.new(0, cfg.LODGE.COUNTER.Y / 2 + 0.17, 0)),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		false,
		shop
	)
	-- A `SurfaceGui`'s `Front` face is the part's own -Z, which is also its LookVector -- so a board
	-- left unrotated on the north wall already reads into the room, and the half turn this had put
	-- the word SHOP face down in the logs. Photographed, not reasoned about.
	sign(
		"ShopSign",
		Vector3.new(8, 2.2, 0.3),
		CFrame.new(counterAt.X, origin.Y + math.min(7.4, room.height - 1.6), origin.Z + room.halfZ - 0.3),
		cfg.LODGE.SIGN_TEXT,
		shop
	)
	-- THE MAN BEHIND IT (task 181). `origin.Y` is the floor the counter stands on, which is what he
	-- stands on too -- the one number, read in one place.
	shopkeeper(shop, counterAt, origin.Y, cfg, seams)

	trophies(inside, room, cfg)
end

-- THE LODGE. One build, ours, and every piece of it is a part in this file.
local function lodge(container: Instance, anchor: Vector3, cfg, seams: Seams?): Instance
	local folder = Instance.new("Folder")
	folder.Name = "Lodge"
	local origin = anchor + cfg.LODGE.OFFSET
	local size = cfg.LODGE.SIZE
	local d = cfg.LODGE.LOG_DIAMETER
	local halfX, halfZ = size.X / 2, size.Z / 2
	local floorY = floorYOf(origin, cfg)
	local wallTop = floorY + coursesOf(cfg) * d

	-- THE STONE PLINTH, SUNK INTO THE GROUND. Roblox terrain is voxelised and its real surface sits
	-- up to a stud below the shelf the arithmetic predicts -- MEASURED on this very yard in task 186,
	-- where every tyre of all four trucks stood 0.752 studs under it. A building cannot be settled
	-- per wheel, so it is given a plinth that starts two studs under the ground instead: there is no
	-- height at which a stone base can be caught floating.
	part(
		"Plinth",
		Vector3.new(
			size.X + 2 * cfg.LODGE.PLINTH.OVERHANG,
			cfg.LODGE.PLINTH.HEIGHT + 2,
			size.Z + 2 * cfg.LODGE.PLINTH.OVERHANG
		),
		CFrame.new(origin.X, origin.Y + cfg.LODGE.PLINTH.HEIGHT / 2 - 1, origin.Z),
		cfg.LODGE.PLINTH.COLOR,
		cfg.LODGE.PLINTH.MATERIAL,
		true,
		folder
	)
	part(
		"PlinthCap",
		Vector3.new(size.X + 2 * cfg.LODGE.PLINTH.OVERHANG + 0.6, 0.5, size.Z + 2 * cfg.LODGE.PLINTH.OVERHANG + 0.6),
		CFrame.new(origin.X, origin.Y + cfg.LODGE.PLINTH.HEIGHT - 0.25, origin.Z),
		cfg.LODGE.PLINTH.CAP_COLOR,
		Enum.Material.Slate,
		false,
		folder
	)
	part(
		"Floor",
		Vector3.new(size.X, cfg.LODGE.FLOOR_THICK, size.Z),
		CFrame.new(origin.X, floorY - cfg.LODGE.FLOOR_THICK / 2, origin.Z),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		true,
		folder
	)

	-- THE OPENINGS, PER WALL, AND THEY ARE THE SAME TABLE THE WINDOWS ARE HUNG FROM. One list, read
	-- twice -- once to cut the logs and once to dress the hole -- so a window can never be fitted to
	-- a wall that was not cut for it.
	local holes: { [string]: { Opening } } = { south = {}, north = {}, west = {}, east = {} }
	table.insert(holes.south, {
		along = origin.X,
		width = cfg.LODGE.DOOR.WIDTH,
		bottom = floorY,
		top = floorY + cfg.LODGE.DOOR.HEIGHT,
	})
	local win = cfg.LODGE.WINDOW
	for _, row in ipairs(cfg.LODGE.WINDOWS) do
		-- INTO THE WORLD, HERE, ONCE: a north or south wall runs along x and an east or west wall
		-- along z, so which of the lodge's two centres the row is measured from is decided by its
		-- own wall and nowhere else.
		local alongWorld = if row.wall == "north" or row.wall == "south"
			then origin.X + row.along
			else origin.Z + row.along
		table.insert(holes[row.wall], {
			along = alongWorld,
			width = win.WIDTH,
			bottom = floorY + win.SILL_STUDS,
			top = floorY + win.SILL_STUDS + win.HEIGHT,
		})
	end

	logWall(folder, "WallS", "x", size.X - 2 * d, origin.X, origin.Z - halfZ + d / 2, floorY, cfg, holes.south)
	logWall(folder, "WallN", "x", size.X - 2 * d, origin.X, origin.Z + halfZ - d / 2, floorY, cfg, holes.north)
	logWall(folder, "WallW", "z", size.Z - 2 * d, origin.Z, origin.X - halfX + d / 2, floorY, cfg, holes.west)
	logWall(folder, "WallE", "z", size.Z - 2 * d, origin.Z, origin.X + halfX - d / 2, floorY, cfg, holes.east)
	corners(folder, origin, floorY, cfg)

	-- THE WINDOWS, each in the hole its own row cut. `face` looks OUTWARD, so the yaw is the wall's
	-- outward normal and the one `trophies` uses is its opposite.
	for index, row in ipairs(cfg.LODGE.WINDOWS) do
		local y = floorY + win.SILL_STUDS + win.HEIGHT / 2
		local at, yaw
		if row.wall == "south" then
			at, yaw = Vector3.new(origin.X + row.along, y, origin.Z - halfZ + d / 2), math.pi
		elseif row.wall == "north" then
			at, yaw = Vector3.new(origin.X + row.along, y, origin.Z + halfZ - d / 2), 0
		elseif row.wall == "west" then
			at, yaw = Vector3.new(origin.X - halfX + d / 2, y, origin.Z + row.along), math.pi / 2
		else
			at, yaw = Vector3.new(origin.X + halfX - d / 2, y, origin.Z + row.along), -math.pi / 2
		end
		windowUnit(folder, string.format("%d", index), CFrame.new(at) * CFrame.Angles(0, yaw, 0), cfg)
	end

	doorway(folder, origin, floorY, cfg)
	roof(folder, origin, wallTop, cfg)
	chimney(folder, origin, cfg)

	-- ANTLERS OVER THE DOOR. Karen's own word, task 177, and now the same mount the wall inside uses
	-- -- so the thing over the door and the things on the trophy wall are one piece of code.
	local over = Instance.new("Folder")
	over.Name = "Antlers"
	over.Parent = folder
	antlerMount(
		over,
		"DoorStag",
		CFrame.new(origin.X, floorY + cfg.LODGE.DOOR.HEIGHT + 5.2, origin.Z - halfZ - 0.4)
			* CFrame.Angles(0, math.pi, 0),
		cfg.TROPHIES.GABLE,
		cfg
	)

	porch(folder, origin, floorY, wallTop, cfg)
	interior(folder, Build.roomFor(anchor, cfg), cfg, seams)
	folder.Parent = container
	return folder
end

-- ---------------------------------------------------------------- the truck

-- WHAT A PART OF A TRUCK IS, FOR THE REPAINT (task 186). PURE, and exported so the rule is a spec
-- rather than a belief about a free model nobody can read in a diff.
--
-- KAREN, 2026-10-14 ~21:15: *"make cars comoflash like military like hunting cars"*.
--
-- IT ANSWERS BY NAME AND BY MATERIAL, IN THAT ORDER, and the order is the whole of it: `WindowFrame`
-- carries both words, and a frame round a window that got painted olive is a window with an olive
-- bar across it. Glass first, then the lamps, then the wheels, and only what is left is paint.
--
-- "keep" IS THE DEFAULT FOR EVERYTHING THIS SYSTEM DID NOT BUILD. The model ships its bumpers,
-- grilles, mirrors and interior at RGB 17,17,17 -- near black, which is what a military truck's trim
-- is anyway -- so the repaint touches the PANELS and the WHEELS and nothing else. A painter that
-- recoloured every part it did not recognise would be a painter that cannot be given a new model.
--
-- Measured in the live place, 2026-10-14: the eight body panels are MeshParts named `Color`,
-- `SmoothPlastic`, RGB 163,162,165, with no `TextureID` and no `SurfaceAppearance`.
local TRUCK_BODY_WORDS = { "color", "colour", "bed", "cab", "bonnet", "hood", "panel", "body", "door" }

function Build.truckSkinOf(name: string, material: Enum.Material): string
	local lower = string.lower(name)
	if material == Enum.Material.Glass or string.find(lower, "glass") or string.find(lower, "window") then
		return "glass"
	end
	if material == Enum.Material.Neon or string.find(lower, "light") then
		return "light"
	end
	if string.find(lower, "tire") or string.find(lower, "tyre") or string.find(lower, "wheel") then
		return "tyre"
	end
	if string.find(lower, "rim") then
		return "rim"
	end
	for _, word in ipairs(TRUCK_BODY_WORDS) do
		if string.find(lower, word) then
			return "body"
		end
	end
	return "keep"
end

-- EVERY PART OF A THING, ROOT INCLUDED, so one settle and one repaint serve BOTH branches: the free
-- model is a `Model` and task 177's truck is a `Folder`, and neither may need its own geometry.
local function partsOf(root: Instance): { BasePart }
	local out = {}
	if root:IsA("BasePart") then
		table.insert(out, root :: BasePart)
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(out, descendant :: BasePart)
		end
	end
	return out
end

-- THE CAMOUFLAGE, PAINTED ON WHATEVER GOT BUILT. `index` is the bay, so the four palettes wrap the
-- way `PADS.COLOURS` does and a fifth bay cannot index past the end.
--
-- THE PANELS ALTERNATE THROUGH THE PALETTE in the order they are met, which is stable for a clone of
-- a fixed model: that is what makes the shell, the bonnet and the doors three different tones --
-- a scheme -- instead of one flat olive rectangle.
--
-- Returns how many parts it painted, for `stats.truckPainted`: "the trucks are camouflaged" has to
-- be a number the console can print, not something read off a screenshot alone.
local function camo(root: Instance, index: number, cfg): number
	local spec = cfg.TRUCK.CAMO
	local palette = spec.TONES[(index - 1) % #spec.TONES + 1]
	local painted, panel = 0, 0
	for _, piece in ipairs(partsOf(root)) do
		local skin = Build.truckSkinOf(piece.Name, piece.Material)
		if skin == "body" then
			piece.Color = palette[panel % #palette + 1]
			piece.Material = spec.BODY_MATERIAL
			piece.Reflectance = 0
			panel += 1
			painted += 1
		elseif skin == "tyre" then
			piece.Color = spec.TYRE
			piece.Reflectance = 0
			painted += 1
		elseif skin == "rim" then
			piece.Color = spec.RIM
			piece.Reflectance = 0
			painted += 1
		end
	end
	return painted
end

-- WHERE A TRUCK TOUCHES THE GROUND: one contact per WHEEL, measured off the parts that were actually
-- built (task 186). `bottom` is the lowest point of that wheel -- exact for a frame that is only
-- yawed, and within 0.01 studs under the tilt this applies (1.5 studs of radius at 6 degrees).
--
-- A MODEL WITH NO PART CALLED A WHEEL FALLS BACK ON ITS OWN FOOTPRINT, and that branch is not
-- hypothetical: the lobby spec's stand-in truck is a single Part named `Body`, and so is any
-- replacement model whose author named the wheels in another language. Four corners of the footprint,
-- pulled in to `FOOTPRINT_INSET` of the half-span so a corner sample cannot fall off the shelf.
local FOOTPRINT_INSET = 0.6

local function contactsOf(parts: { BasePart }): { { x: number, z: number, bottom: number } }
	local out = {}
	for _, piece in ipairs(parts) do
		if Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
			table.insert(out, {
				x = piece.Position.X,
				z = piece.Position.Z,
				bottom = piece.Position.Y - piece.Size.Y / 2,
			})
		end
	end
	if #out > 0 then
		return out
	end
	local minX, maxX, minZ, maxZ, lowest = math.huge, -math.huge, math.huge, -math.huge, math.huge
	for _, piece in ipairs(parts) do
		local half = piece.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = piece.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
					minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
					lowest = math.min(lowest, corner.Y)
				end
			end
		end
	end
	if lowest == math.huge then
		return out
	end
	local midX, midZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	local halfX, halfZ = (maxX - minX) / 2 * FOOTPRINT_INSET, (maxZ - minZ) / 2 * FOOTPRINT_INSET
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(out, { x = midX + sx * halfX, z = midZ + sz * halfZ, bottom = lowest })
		end
	end
	return out
end

-- THE PLANE THROUGH THE GROUND UNDER ONE TRUCK. PURE, exported, and it is least squares rather than
-- three-points-make-a-plane for one reason: four wheels are four samples and the fourth one is not
-- redundant -- it is the one that says whether the yard really is a plane here.
--
-- Returns the two slopes, dy/dx and dy/dz. Fewer than three samples, or samples that are all in a
-- line (a determinant at zero), answer level: a truck that cannot be fitted is a truck that stays
-- flat, never one tipped by a divide by nothing.
function Build.groundFit(points: { { x: number, z: number, y: number } }): (number, number)
	local n = #points
	if n < 3 then
		return 0, 0
	end
	local midX, midZ, midY = 0, 0, 0
	for _, point in ipairs(points) do
		midX, midZ, midY = midX + point.x, midZ + point.z, midY + point.y
	end
	midX, midZ, midY = midX / n, midZ / n, midY / n
	local sxx, szz, sxz, sxy, szy = 0, 0, 0, 0, 0
	for _, point in ipairs(points) do
		local dx, dz, dy = point.x - midX, point.z - midZ, point.y - midY
		sxx += dx * dx
		szz += dz * dz
		sxz += dx * dz
		sxy += dx * dy
		szy += dz * dy
	end
	local det = sxx * szz - sxz * sxz
	if math.abs(det) < 1e-9 then
		return 0, 0
	end
	return (sxy * szz - szy * sxz) / det, (szy * sxx - sxy * sxz) / det
end

-- THE ROTATION THAT STANDS A TRUCK ON THAT PLANE. PURE, exported, and CLAMPED AT BOTH ENDS: under
-- `minRadians` the ground is level and a tilt would be noise, and over `maxRadians` the answer is a
-- bad ray rather than a slope -- a truck lying on its side in a car park is a worse bug than the one
-- this fixes.
--
--   CFrame.fromAxisAngle  https://create.roblox.com/docs/reference/engine/datatypes/CFrame
--
-- It turns the WORLD's up onto the plane's normal, so it composes with the truck's yaw from the
-- left (`tilt * rotation`) and the truck keeps pointing down the track.
function Build.tiltFrom(slopeX: number, slopeZ: number, minRadians: number, maxRadians: number): CFrame
	local normal = Vector3.new(-slopeX, 1, -slopeZ).Unit
	local axis = Vector3.new(0, 1, 0):Cross(normal)
	local sin = math.clamp(axis.Magnitude, 0, 1)
	if sin < 1e-6 then
		return CFrame.identity
	end
	local angle = math.asin(sin)
	if angle < minRadians then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.min(angle, maxRadians))
end

-- SETTLE ONE TRUCK ONTO THE GROUND THAT IS REALLY THERE (task 186). Karen: *"car tyers are inside
-- earth"*.
--
-- THE SAME READER THE PADS USE, AND THE SAME LOWER BOUND. `groundAt` is the world's one ground
-- reader; `floorY` is the top of the yard slab this system lays itself, and `math.max` of the two
-- keeps both guarantees at once -- above whatever the ground really is, and never sunk into a slab
-- of our own. It is `pad`'s rule, two functions down, applied to a heavier object.
--
-- WHY IT RUNS AFTER THE BUILD AND NOT INSTEAD OF IT: `at.Y` is still where the truck is PARKED and
-- `sitOnShelf` still stands it on that number. This measures what the engine actually produced under
-- the wheels it actually built, which is the one thing no arithmetic upstream can know.
--
-- TWO PASSES, AND THE SECOND ONE IS NOT A REFINEMENT. The tilt moves every wheel sideways as well as
-- up, so the ground under it is a different question afterwards; measuring again is what makes the
-- lift exact rather than first-order. The ray is cheap (8 per truck) and this runs once, at build.
--
-- Returns the lift it applied and the worst residual left -- how far the worst wheel ends ABOVE its
-- ground, which is the number `lobby.spec` holds to 0.2 studs and the console prints.
local function settleOnGround(
	root: Instance,
	cfg,
	groundAt: ((number, number) -> number?)?,
	floorY: number
): (boolean, number, number)
	if groundAt == nil then
		return false, 0, 0
	end
	local spec = cfg.TRUCK.SETTLE
	local parts = partsOf(root)
	-- WHERE THE GROUND IS UNDER EACH CONTACT, OR NOTHING AT ALL. A reader that throws, or that
	-- answers nil for even one wheel, leaves the truck exactly where the arithmetic put it: half a
	-- measurement is how a truck ends up tilted onto a wheel whose ground nobody knows.
	local function sample(
		contacts: { { x: number, z: number, bottom: number } }
	): { { x: number, z: number, y: number, bottom: number } }?
		local out = {}
		for _, contact in ipairs(contacts) do
			local ok, measured = pcall(groundAt :: any, contact.x, contact.z)
			if not ok or type(measured) ~= "number" then
				return nil
			end
			table.insert(out, {
				x = contact.x,
				z = contact.z,
				y = math.max(measured :: number, floorY),
				bottom = contact.bottom,
			})
		end
		return out
	end

	local first = sample(contactsOf(parts))
	if first == nil or #first == 0 then
		return false, 0, 0
	end
	local slopeX, slopeZ = Build.groundFit(first :: any)
	local tilt = Build.tiltFrom(slopeX, slopeZ, math.rad(spec.MIN_TILT_DEGREES), math.rad(spec.MAX_TILT_DEGREES))
	if tilt ~= CFrame.identity then
		-- ROTATED ABOUT THE CONTACT PATCH'S OWN CENTRE, not about the model's pivot: turning a truck
		-- about a point five studs over its wheels would lift one end of it into the air and leave
		-- the lift below to put it back.
		local midX, midZ, midY = 0, 0, 0
		for _, point in ipairs(first :: any) do
			midX, midZ, midY = midX + point.x, midZ + point.z, midY + point.bottom
		end
		local n = #(first :: any)
		local pivot = Vector3.new(midX / n, midY / n, midZ / n)
		local delta = CFrame.new(pivot) * tilt * CFrame.new(-pivot)
		for _, piece in ipairs(parts) do
			piece.CFrame = delta * piece.CFrame
		end
	end

	local second = sample(contactsOf(parts))
	if second == nil or #second == 0 then
		return false, 0, 0
	end
	local lift = -math.huge
	for _, point in ipairs(second :: any) do
		lift = math.max(lift, point.y - point.bottom)
	end
	if lift ~= 0 then
		local up = CFrame.new(0, lift, 0)
		for _, piece in ipairs(parts) do
			piece.CFrame = up * piece.CFrame
		end
	end
	-- AND WHAT IT ACTUALLY LEFT, measured off the parts as they now stand -- never computed from the
	-- lift, which is the arithmetic this whole function exists to stop trusting.
	local worst = 0
	for _, point in ipairs(second :: any) do
		worst = math.max(worst, math.abs((point.bottom + lift) - point.y))
	end
	return true, lift, worst
end

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
local function trucks(
	container: Instance,
	anchor: Vector3,
	cfg,
	templates: Instance?,
	groundAt: ((number, number) -> number?)?
)
	local folder = Instance.new("Folder")
	folder.Name = "Trucks"
	local model = cfg.TRUCK.MODEL
	-- THE TOP OF THE YARD SLAB, which is the surface a truck in a parked bay stands on when the
	-- terrain under it is lower. `road` lays `Yard` across all four bays at `anchor.Y + THICK / 2`,
	-- so its top is `anchor.Y + THICK` -- the same bound `pad` holds its deck above, for the same
	-- reason and out of the same row.
	local floorY = anchor.Y + cfg.ROAD.THICK_STUDS
	for index = 1, cfg.TRUCK.COUNT do
		local at = anchor + cfg.TRUCK.OFFSET + Vector3.new((index - 1) * cfg.TRUCK.BAY_GAP_STUDS, 0, 0)
		local name = string.format("Truck%d", index)
		local made = clone(templates, Data.TEMPLATE.TRUCK, name, model.SCALE, at, model.YAW_RADIANS, folder, false)
		if made == nil then
			made = truck(folder, at, cfg, name)
		end
		-- PAINTED FIRST AND SETTLED SECOND, and the order is only readability: one reads the parts
		-- and the other moves them, so neither can see the other's work.
		stats.truckPainted += camo(made :: Instance, index, cfg)
		local settled, _lift, worst = settleOnGround(made :: Instance, cfg, groundAt, floorY)
		if settled then
			stats.trucksSettled += 1
			stats.truckGroundStuds = math.max(stats.truckGroundStuds, worst)
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
-- THEY ARE LAID ON THE GROUND THAT IS MEASURED, NOT ON THE SHELF THE ARITHMETIC PREDICTS, and that
-- is the one thing this task had to correct after looking at a picture (`pad`'s own comment below).
-- Task 177's circle used the shelf, which is why its header said a raycast would be *"measuring a
-- surface this system built itself"* -- true of the ROAD slab, and false of the TERRAIN, whose
-- surface the engine rounds to its own voxel grid.

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
	--
	-- ...AND IT IS BOUNDED FROM BELOW BY THE SLAB, which is the half of the design's guarantee the
	-- measurement must not throw away (the Reviewer's round-1 note). A pad straddles the terrain AND
	-- the `Yard` / `Lane` parts, whose top is `shelfY + ROAD.THICK_STUDS`; a probe answering below
	-- that -- a dip, or a reader that measured terrain under an opaque slab -- would bury the deck in
	-- exactly the way task 177's ring was buried. `math.max` keeps BOTH guarantees: above whatever
	-- the ground really is, and never inside a slab this system laid itself.
	if groundAt ~= nil then
		local ok, measured = pcall(groundAt, centre.X, centre.Z)
		if ok and type(measured) == "number" then
			local surface = math.max(measured :: number, anchor.Y + cfg.ROAD.THICK_STUDS)
			centre = Vector3.new(centre.X, surface + config.LIFT_STUDS - size.Y / 2, centre.Z)
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
	-- THE WORDS COME FROM `Pads.labelFor` AND FROM NOWHERE ELSE -- here and in `setPad` below -- so
	-- there is ONE formatter of what a board says (the Reviewer's round-1 note: the two lines used to
	-- be built in both files off the same table, which is two places to change one format).
	local truckLine, countLine = Pads.labelFor(Pads.empty(index), cfg)
	boardLabel("Truck", config.BILLBOARD.TRUCK_PX, 0, colour, truckLine)
	boardLabel(
		"Count",
		config.BILLBOARD.COUNT_PX,
		config.BILLBOARD.TRUCK_PX + 6,
		Color3.fromRGB(246, 240, 230),
		countLine
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
-- `truckText` AND `countText` ARRIVE READY, from `Pads.labelFor`, because the WORDS are the pure
-- module's and the WRITE is this one's -- the `Build.faceKeeper` split again, and what keeps one
-- format of `n / size` in the repository.
function Build.setPad(index: number, state: string, firstUserId: number?, truckText: string, countText: string): boolean
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
	stats.trucksSettled = 0
	stats.truckGroundStuds = 0
	stats.truckPainted = 0
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
	lodge(folder, anchor, cfg, seams)
	-- THE WORLD'S GROUND READER REACHES THE TRUCKS TOO (task 186), for the reason it already reaches
	-- the pads: the shelf the arithmetic predicts is not the surface the engine produced, and a truck
	-- stood on the prediction has its tyres 0.75 studs inside the terrain -- measured, in this place,
	-- on every one of them.
	trucks(folder, anchor, cfg, templates, (seams or {}).groundAt)
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
