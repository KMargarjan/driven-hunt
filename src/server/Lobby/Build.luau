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
-- SINCE TASK 180 SOME OF IT IS CLONED, AND WHICH PIECES RAN IS A COUNTED FACT. Karen, 2026-10-14:
-- *"we need car truck model or hunting bus also use free model"*. So the four TRUCKS and the TREE
-- LINE are clones of script-free free Creator Store models parked in `Workspace.LobbyAssets` (Studio
-- content, which Rojo does not manage and Connect does not delete), and a parts build is what
-- happens when a template is not there -- per piece, so a missing truck costs you nothing else.
--
-- THE LODGE IS NOT ONE OF THEM ANY MORE (task 187): the house, everything inside it and every antler
-- on its walls are built here, from parts, because Karen judged the free cabins *"garbadge"*. There
-- is exactly one lodge and no template can bring another back.
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
-- WHERE A TREE MEETS THE GROUND, as arithmetic (task 199). The junction rule part 3e invented here
-- now lives in one module, because `Workspace.OurForest` needs the SAME rule and is re-seated by a
-- tool rather than by this build: `tools/forest_ground.py` injects that module's own source into
-- the Luau it sends to Studio, so there is one copy of the arithmetic and no way for the two to
-- drift apart (lesson L-031).
local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
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
	-- WHERE THE **TERRAIN** IS, which is a different question (task 196 part 3d). `groundAt` rays
	-- past `OurForest`, `Foliage` and `Boars`, but MEASURED in this place that is not every tree:
	-- a downward ray can still stop on another tree's canopy, on a road part, or on a fence. For a
	-- beater that is a spawn a little high; for a TREE it is a tree standing on air, which is what
	-- Karen photographed. `ForestTest.terrainYAt` includes nothing but `Workspace.Terrain` and so
	-- cannot answer anything but the ground. nil falls back to `groundAt`, and then to arithmetic.
	terrainAt: ((number, number) -> number?)?,
	-- IS THE SHOP IN THIS BUILD AT ALL? The `SHOP` flag's value, read ONCE at the composition root
	-- and passed inward (CLAUDE.md, feature flags), because this module must not learn what a shop
	-- is. It decides one thing: whether the keeper's prompt is `Enabled`. With the shop off the
	-- panel is dead, and a live "Press E" over a man who answers nothing is worse than no prompt.
	-- nil is "nobody said", which is a prompt that works -- the state a spec builds in.
	shopOn: boolean?,
	-- WHAT A THING IN THE GAME LOOKS LIKE, by this module's own vocabulary (task 196): `"boar"` for
	-- the trophy on the chimney breast, `"shotgun"` and `"rifle"` for the rack behind the counter.
	-- The composition root translates a name into a template -- the `Body.setAccessorySource` seam
	-- exactly, and for its stated reason: *"`Match.Body` must not learn what `ServerStorage.Assets`
	-- calls anything"*. nil, or a nil answer, means that thing is not drawn: a bare plaque and an
	-- empty rack, never a crash and never a grey box pretending to be an animal.
	assets: ((string) -> Instance?)?,
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
	-- HOW MANY TIMES A TRUCK WAS ACTUALLY STARTED OR STOPPED (task 197). `Build.setTruck` is
	-- edge-triggered and asked every scan, so this is `padWrites`' own rule applied to the engine: a
	-- number that climbs with the owner's `scans` is the bug the counter exists to show.
	truckWrites = 0,
	-- ...AND HOW MANY OF THE FOUR GOT A RIG AT ALL, so "the trucks can light up" is a number the
	-- boot's log line and the spec can read rather than a belief.
	truckRigs = 0,
	-- HOW MANY TREE PARTS WERE REPAINTED AS ALDER (spec 16b): a counted fact about the build, beside
	-- `truckPainted` and for the same reason.
	treesTinted = 0,
	treesMoved = 0,
	treesSeated = 0,
	treesDropped = 0,
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

-- A CLIP: a part that stops a BODY and nothing else (task 195). Valve's `tools/toolsplayerclip`,
-- read as three independent switches on one Roblox part (research note sections 3.1 and 3.2):
-- `CanCollide` true so a player cannot pass, `CanQuery` false so no ray -- a pellet, or the
-- keeper's `ProximityPrompt` line-of-sight test -- ever sees it, `CanTouch` false so it fires
-- nothing, invisible and casting no shadow.
--
-- IT IS ONLY EVER PUT FLUSH WITH SOMETHING YOU CAN SEE, which is the one rule the Valve page
-- insists on: an invisible wall standing in open air is a player bumping into nothing.
local function clip(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.CFrame = cframe
	made.Anchored = true
	made.Transparency = 1
	made.CanCollide = true
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Parent = parent
	stats.parts += 1
	stats.solids += 1
	return made
end

-- A LOG: a cylinder lying along one horizontal axis. `axis` is "x" or "z", which is the only
-- freedom a log wall needs, so there is no rotation to get wrong.
-- ONE LOG. `course` IS OPTIONAL AND DECIDES ITS TONE (the Designer's lodge spec, 2026-10-16,
-- sections 1a and 6): a log wall is never one colour, and alternating the courses is what turns a
-- stack of identical cylinders into timber. nil keeps the odd-course tone, which is what every
-- caller that does not care gets.
local function log(
	name: string,
	length: number,
	centre: Vector3,
	axis: string,
	cfg,
	parent: Instance,
	course: number?
): Part
	local d = cfg.LODGE.LOG_DIAMETER
	local made = part(
		name,
		Vector3.new(length, d, d),
		CFrame.new(centre) * (if axis == "z" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity),
		if course ~= nil and course % 2 == 0 then cfg.LODGE.LOG_COLOR_ALT else cfg.LODGE.LOG_COLOR,
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
	local board = part(name, size, cframe, Color3.fromRGB(58, 44, 32), Enum.Material.Wood, false, parent)
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
			-- `ScaleTo` IS ABSOLUTE AGAINST THE AUTHORED SIZE, NOT A MULTIPLIER OF WHAT YOU SEE
			-- (https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo). A template a
			-- human scaled down in Studio carries that factor in `GetScale()`, and `ScaleTo(0.95)`
			-- throws it away and rebuilds the model at 0.95 of its RAW IMPORT.
			--
			-- MEASURED, 2026-10-16, which is the only reason this was ever found:
			-- `LobbyAssets.Trees.SilverBirch_Var11_LOD_0` displays 27 x 74 x 27 and reports
			-- `GetScale() = 0.04329`, so `ScaleTo(0.95)` made it **1629 studs tall** -- twenty-two
			-- times the tree in the folder, and twenty times `OurForest`'s own 81-stud aspens. That
			-- is the thing in the photographs: trunks crossing the roof, a trunk hanging through
			-- the porch, and the *"what's wrong with those trees next to house"* Karen reported.
			-- The other scaled template, the forest oak, reports 0.19487 and came out at 294.
			--
			-- `scale` is meant to be a multiplier of the template AS IT STANDS, so it is multiplied.
			-- Every other template in `LobbyAssets` reports exactly 1.0 (the truck, the lodge, the
			-- two heads), so this changes nothing but the trees -- checked before the edit.
			made:ScaleTo(made:GetScale() * scale)
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
			-- A FUZZ, because both sides of this comparison are sums of the same floats arrived at
			-- two different ways: an opening snapped to a course boundary lands on 3.6000000000000005
			-- against a course top of 3.5999999999999996, and the course below the window was dropped
			-- too -- a two-stud slot under every sill, which is round 1's finding coming back through
			-- the arithmetic rather than through the design.
			if y + d / 2 > hole.bottom + 1e-4 and y - d / 2 < hole.top - 1e-4 then
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
				log(string.format("%s%d_%d", name, course, index), span, centre, axis, cfg, folder, course)
				placed += 1
			end
		end
	end
	return placed
end

-- WHERE A HOLE REALLY STARTS AND STOPS. A log is a whole cylinder: a course that overlaps an
-- opening at all is DROPPED, so the hole in the wall is always a whole number of courses -- and a
-- frame sized to the nominal opening therefore leaves daylight above and below it. Measured by the
-- Reviewer on round 1: with a 1.8-stud log, a sill at 3.4 and a 4.4-stud window, the wall was open
-- from 1.8 to 9.0 while the glass covered 3.4 to 7.8, which is two open slots per window and eight
-- in the house.
--
-- So the opening is SNAPPED to the course grid here, once, and the same two numbers then cut the
-- wall AND size the frame. Returning them rather than hiding them inside the wall builder is the
-- whole point: the dressing cannot drift from the hole if both read the same answer.
--
-- Course k occupies `[baseY + (k-1)d, baseY + kd]`, and the cut test is strict (`y + d/2 > bottom`),
-- so a hole that starts exactly on a boundary drops exactly the courses above it.
local function snapOpening(baseY: number, bottom: number, top: number, d: number): (number, number)
	local lower = math.floor((bottom - baseY) / d + 0.5) * d + baseY
	local upper = math.floor((top - baseY) / d + 0.5) * d + baseY
	if upper - lower < d then
		upper = lower + d
	end
	return lower, upper
end

-- THE CORNERS, AND THEY ARE THE WHOLE REASON THIS READS AS A LOG BUILDING AND NOT AS FOUR FENCES.
-- One stub per corner per course, turned a quarter turn every course, so the ends criss-cross the
-- way a notched corner does -- "corners with protruding beam ends, called projections ... the
-- projection cuts in logs are made around 15 to 20 cm from the end of the block" (Glentleiten).
-- `LOG_END_STUDS` is that projection.
--
-- It is also what CLOSES the corner: the two wall runs stop a diameter short of each other, and the
-- stub is the part that fills the square where they would have crossed.
-- THE CORNERS (spec 6). Every course projected by exactly the same 0.9, which reads MACHINED; a
-- hand-cut `Blockbau` corner alternates long and short up the stack, and the courses themselves are
-- never one tone.
local function corners(folder: Instance, origin: Vector3, baseY: number, cfg): number
	local d = cfg.LODGE.LOG_DIAMETER
	local halfX, halfZ = cfg.LODGE.SIZE.X / 2 - d / 2, cfg.LODGE.SIZE.Z / 2 - d / 2
	local placed = 0
	for course = 1, coursesOf(cfg) do
		local y = baseY + d / 2 + (course - 1) * d
		local axis = if course % 2 == 1 then "x" else "z"
		local out = if course % 2 == 1 then cfg.LODGE.LOG_END_STUDS else cfg.LODGE.LOG_END_ALT_STUDS
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				log(
					string.format("WallEnd%d%s%s", course, if sx < 0 then "W" else "E", if sz < 0 then "S" else "N"),
					d + 2 * out,
					Vector3.new(origin.X + sx * halfX, y, origin.Z + sz * halfZ),
					axis,
					cfg,
					folder,
					course
				)
				placed += 1
			end
		end
	end
	return placed
end

-- ONE WINDOW, IN A HOLE THE WALL ALREADY LEFT: frame, glass, muntins, a sill and a pair of shutters
-- with the cut-out a Central-European shutter carries (a fir tree here; a heart is the other
-- classic).
--
-- `face` SITS ON THE WALL PLANE WITH ITS LOOKVECTOR POINTING OUT OF THE BUILDING, so **-Z is
-- outdoors** for every offset below and the same function hangs a window on any of the four walls.
-- That sentence was in this comment for a round while two of the four yaws pointed the other way and
-- the shutters swung against the other half of their own window; it is the caller's four numbers and
-- the sign of the hinge angle that make it true, and both now say so where they are written.
--
-- THE GLASS IS SOLID AND THE REST IS NOT. A hole in a log wall that nothing closes is a hole a
-- player walks out of; the pane is what makes the window a window. It keeps `CanQuery`, because the
-- rule the rest of this file follows -- *a slab that stops a pellet changes what the shot hit* -- is
-- about DECORATION, and a wall is not decoration.
local function windowUnit(folder: Instance, name: string, face: CFrame, height: number, cfg)
	local spec = cfg.LODGE.WINDOW
	-- `height` IS THE HOLE'S OWN HEIGHT, not the config's: the wall is cut by whole log courses, so
	-- what `WINDOW.HEIGHT` asks for and what the wall gives are two different numbers and the frame
	-- has to be built to the second one (round 1, finding 1).
	local w, h, f = spec.WIDTH, height, spec.FRAME
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
			-- 2.30 DEEP AND NOT 1.10 (the Designer's lodge spec, 2026-10-16, section 7): a 1.1-deep
			-- jamb in a 1.8-stud wall leaves the CUT LOG CYLINDERS AND END-GRAIN showing inside the
			-- reveal (image 20). At 2.30 the lining runs right through and stands 0.25 proud of each
			-- face.
			Vector3.new(f, h + 2 * f, 2.3),
			face * CFrame.new(side * (w + f) / 2, 0, -0.1),
			spec.FRAME_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
	end
	part(
		string.format("WindowHead%s", name),
		Vector3.new(w + 2 * f, f, 2.3),
		face * CFrame.new(0, (h + f) / 2, -0.1),
		spec.FRAME_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	-- THE SILL IS DEEPER THAN THE FRAME and proud of it on both sides: that shadow line under a
	-- window is most of what makes one read as built rather than drawn.
	part(
		string.format("WindowSill%s", name),
		Vector3.new(w + 2 * f + 1.2, f * 1.4, 3.2),
		face * CFrame.new(0, -(h + f * 1.4) / 2, -0.75),
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
	-- THE SWING IS OUTWARD, LIKE EVERYTHING ELSE ON THIS WINDOW. With the turn the other way the
	-- leaf's own offset came back as +0.94 in local Z -- BEHIND the face -- so the shutters were
	-- inside the room while the sill was outside it, and no yaw could put both on the same side of
	-- the wall (round 2, finding 1). `R_y(t) * (a, 0, 0) = (a cos t, 0, -a sin t)`, so the sign of
	-- `t` is the sign of the leaf's local Z, and -Z is out.
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "W" else "E"
		local hinge = face
			* CFrame.new(side * (w / 2 + f), 0, -0.45)
			* CFrame.Angles(0, side * spec.SHUTTER_OPEN_RADIANS, 0)
		local leaf = hinge * CFrame.new(side * w / 4, 0, 0)
		part(
			string.format("Shutter%s%s", name, tag),
			Vector3.new(w / 2, h, 0.35),
			leaf,
			spec.SHUTTER_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
		-- A STRAP HINGE ACROSS THE TOP OF EACH LEAF (the Designer's lodge spec, 2026-10-16, section
		-- 7): the shutters are flat boards with nothing holding them to the wall (image 03).
		part(
			string.format("ShutterHinge%s%s", name, tag),
			Vector3.new(w / 2 - 0.2, 0.16, 0.14),
			leaf * CFrame.new(0, h / 2 - 0.45, -0.19),
			cfg.LODGE.IRON_COLOR,
			Enum.Material.Metal,
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
local function doorway(folder: Instance, origin: Vector3, floorY: number, height: number, cfg)
	local spec = cfg.LODGE.DOOR
	local halfZ = cfg.LODGE.SIZE.Z / 2
	local d = cfg.LODGE.LOG_DIAMETER
	local faceZ = origin.Z - halfZ + d / 2
	for _, side in ipairs({ -1, 1 }) do
		part(
			string.format("DoorPost%s", if side < 0 then "W" else "E"),
			-- 0.3 PROUD OF EACH WALL FACE (spec 8), so the frame reads as a frame.
			Vector3.new(1.3, height + spec.LINTEL_STUDS, d + 1.2),
			CFrame.new(origin.X + side * (spec.WIDTH + 1.1) / 2, floorY + (height + spec.LINTEL_STUDS) / 2, faceZ),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			true,
			folder
		)
	end
	part(
		"DoorLintel",
		Vector3.new(spec.WIDTH + 3.4, spec.LINTEL_STUDS, d + 1.4),
		CFrame.new(origin.X, floorY + height + spec.LINTEL_STUDS / 2, faceZ),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		true,
		folder
	)
	-- THE HEAD BOARD over the lintel (spec 8): a dark board that caps the frame and gives the door a
	-- top edge instead of leaving the lintel's own cut face as the last thing you see.
	part(
		"DoorHeadBoard",
		Vector3.new(spec.WIDTH + 3.4, 0.9, d + 1.8),
		CFrame.new(origin.X, floorY + height + spec.LINTEL_STUDS + 0.45, faceZ),
		Color3.fromHex("241B13"),
		Enum.Material.Wood,
		false,
		folder
	)
	part(
		"DoorThreshold",
		-- WIDER, DEEPER AND DARKER (spec 8): image 22 shows the porch deck and the interior floor
		-- butting at ninety degrees with NOTHING between them. The threshold now laps over both and
		-- is the dark line that joint needs.
		Vector3.new(spec.WIDTH + 2.6, 0.45, d + 2.6),
		CFrame.new(origin.X, floorY + 0.225, faceZ),
		Color3.fromHex("241B13"),
		Enum.Material.Wood,
		false,
		folder
	)
	-- AND THERE IS NO LEAF (task 195). Karen, 2026-10-15: *"doors can be open no doors"*. Task 187's
	-- leaf was hinged with the wrong SIGN -- `R_y(t) * (a,0,0) = (a cos t, 0, -a sin t)`, so a
	-- POSITIVE half-width about a jamb at `-LEAF_OPEN_RADIANS` swings the free edge NORTH, into the
	-- house -- and it was measured standing 1.34 studs inside the room with its bottom 0.2 studs
	-- off the floorboards: a door hanging in mid-air in the middle of the floor, walked through,
	-- which is what *"it's broken there"* and *"all things not hanging"* were about. Flipping the
	-- sign only moves the problem outdoors (a slab at 100 degrees across the porch), and laying the
	-- leaf flat on the wall covers a front window at either jamb, so the leaf GOES. The posts, the
	-- lintel and the threshold are the frame; the opening is the door.
	-- Archived with this reason: `backups/2026-10-16_task-195_door-leaf.txt` (rule 7).
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
		-- THE SLAB'S OWN FRAME, so everything laid on it is placed in studs along the slope rather
		-- than in world y and z (the Designer's lodge spec, 2026-10-16, sections 2 and 4).
		local slab = CFrame.new(Vector3.new(origin.X, (wallTop + ridge) / 2, origin.Z + side * halfZ / 2) + down)
			* CFrame.Angles(side * pitch, 0, 0)
		local slabHalfZ = (slope + spec.EAVE_STUDS) / 2
		-- SHINGLE COURSES INSTEAD OF ONE SLAB (spec 2). The slab stays -- it carries the collision
		-- and closes the roof -- and 14 courses are laid on its outer face from the eave up, each
		-- lapping the one below by 0.40 and alternating two tones. Survey finding 5: *"one flat slab,
		-- mottled dirt-brown, no shingles, no ridge cap, nothing to catch the light"*.
		for course = 1, spec.SHINGLE_COURSES do
			part(
				string.format("Shingle%s%02d", if side < 0 then "S" else "N", course),
				Vector3.new(width, spec.SHINGLE_THICK, spec.SHINGLE_DEPTH),
				slab
					* CFrame.new(
						0,
						spec.THICK / 2 + spec.SHINGLE_THICK / 2,
						slabHalfZ - (course - 0.5) * spec.SHINGLE_STEP
					),
				if course % 2 == 1 then spec.SHINGLE_A else spec.SHINGLE_B,
				Enum.Material.Slate,
				false,
				folder
			)
		end
		-- THE EAVE'S OWN TIMBER (spec 4). Image 02: seven thin battens hanging in the air under each
		-- eave, their inner ends stopping in space, with no purlin and no fascia.
		--
		-- THE RAFTERS ARE RESEATED FROM THE SLAB AND NOT FROM THE WALL TOP, which is the whole fix:
		-- a tail placed in world y guesses where the slab's underside is, and this one IS the slab's
		-- underside -- `-(THICK/2 + 0.275)` puts the tail's top face coplanar with it.
		for index = 1, spec.RAFTERS do
			local x = -size.X / 2 + ((index - 0.5) / spec.RAFTERS) * size.X
			part(
				string.format("Rafter%s%d", if side < 0 then "S" else "N", index),
				Vector3.new(0.55, 0.55, spec.RAFTER_STUDS),
				slab * CFrame.new(x, -(spec.THICK / 2 + 0.275), slabHalfZ - spec.RAFTER_STUDS / 2 - 0.2),
				cfg.LODGE.TIMBER_COLOR,
				Enum.Material.Wood,
				false,
				folder
			)
		end
		-- THE FASCIA closes the shingles' cut ends and gives the eave a line.
		part(
			string.format("Fascia%s", if side < 0 then "S" else "N"),
			Vector3.new(width, 0.75, 0.25),
			slab * CFrame.new(0, -(spec.THICK / 2 + 0.375), slabHalfZ - 0.125),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
		-- THE PURLIN the tails land on, at the wall top.
		part(
			string.format("Purlin%s", if side < 0 then "S" else "N"),
			Vector3.new(width, 0.7, 0.7),
			CFrame.new(origin.X, wallTop + 0.35, origin.Z + side * (halfZ - 0.35)),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
		-- THE BARGE BOARDS, one down each sloping gable edge under the overhang (spec 3).
		for _, half in ipairs({ -1, 1 }) do
			part(
				string.format("Barge%s%s", if side < 0 then "S" else "N", if half < 0 then "W" else "E"),
				Vector3.new(0.3, 0.8, slope + spec.EAVE_STUDS),
				slab * CFrame.new(half * (width / 2 - 0.15), -(spec.THICK / 2 + 0.4), 0),
				spec.BARGE_COLOR,
				Enum.Material.Wood,
				false,
				folder
			)
		end
	end
	-- THE RIDGE CAP SITS ON COURSE 14 rather than being buried in the slabs (spec 2).
	part(
		"RoofRidge",
		Vector3.new(width + 0.6, 0.55, 2.4),
		CFrame.new(origin.X, ridge + 0.5, origin.Z),
		spec.RIDGE_COLOR,
		spec.MATERIAL,
		false,
		folder
	)
	-- THE TWO GABLE TRIANGLES, as boarded wedges: a WedgePart's slope runs along its own +Z, so one
	-- is turned to face the other. `side` is the z half and `half` is the gable END (west or east),
	-- which is why the vertical boarding below hangs off `half` and not off `side`.
	for _, side in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local wedge = Instance.new("WedgePart")
			wedge.Name = string.format("Gable%s%s", if side < 0 then "S" else "N", if half < 0 then "W" else "E")
			wedge.Size = Vector3.new(0.9, rise, halfZ)
			wedge.Anchored = true
			wedge.Color = spec.GABLE_COLOR
			wedge.Material = Enum.Material.Wood
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
		-- VERTICAL BOARDING ON THE GABLE (spec 3). An alpine gable is boarded vertically, and the
		-- wedge's horizontal grain is the reason the triangle reads as BRICK against the logs under
		-- it (images 03, 04, 13). Nine boards a side, each as tall as the triangle is at its own z.
		for board = 1, spec.GABLE_BOARDS do
			local z = (board - (spec.GABLE_BOARDS + 1) / 2) * (size.Z / (spec.GABLE_BOARDS + 0.5))
			local height = rise * (1 - math.abs(z) / halfZ)
			if height > 0.4 then
				part(
					string.format("GableBoard%s%d", if side < 0 then "W" else "E", board),
					Vector3.new(0.22, height, 2.6),
					CFrame.new(origin.X + side * (size.X / 2 + 0.11), wallTop + height / 2, origin.Z + z),
					spec.GABLE_BOARD,
					Enum.Material.Wood,
					false,
					folder
				)
			end
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
	-- A SHOULDERED STACK, NOT A SLAB (the Designer's lodge spec, 2026-10-16, section 5). Image 04:
	-- one 4.4 x 6.5 slab of the same section from the ground to above the ridge. A real stack is
	-- WIDE at the base where it takes the fireplace, steps in at the wall top on a shoulder, and
	-- steps out again on a corbel under the cap -- which is also why it stops reading as stuck on.
	local wallTop = origin.Y + coursesOf(cfg) * cfg.LODGE.LOG_DIAMETER
	part(
		"ChimneyBase",
		Vector3.new(spec.BASE_WIDTH, wallTop - base, spec.BASE_DEPTH),
		CFrame.new(x, (wallTop + base) / 2, z),
		spec.COLOR,
		spec.MATERIAL,
		true,
		folder
	)
	part(
		"ChimneyShoulder",
		Vector3.new(spec.BASE_WIDTH + 0.4, spec.SHOULDER_STUDS, spec.BASE_DEPTH + 0.4),
		CFrame.new(x, wallTop + spec.SHOULDER_STUDS / 2, z),
		spec.CAP_COLOR,
		Enum.Material.Slate,
		false,
		folder
	)
	part(
		"ChimneyStack",
		Vector3.new(spec.STACK_WIDTH, top - wallTop - spec.SHOULDER_STUDS, spec.STACK_DEPTH),
		CFrame.new(x, (top + wallTop + spec.SHOULDER_STUDS) / 2, z),
		spec.COLOR,
		spec.MATERIAL,
		true,
		folder
	)
	part(
		"ChimneyCorbel",
		Vector3.new(spec.STACK_WIDTH + 0.8, spec.CORBEL_STUDS, spec.STACK_DEPTH + 0.8),
		CFrame.new(x, top - 1.1, z),
		spec.CAP_COLOR,
		Enum.Material.Slate,
		false,
		folder
	)
	part(
		"ChimneyCap",
		Vector3.new(spec.STACK_WIDTH + 1.2, 0.8, spec.STACK_DEPTH + 1.2),
		CFrame.new(x, top + 0.4, z),
		spec.CAP_COLOR,
		Enum.Material.Slate,
		false,
		folder
	)
	for index, dz in ipairs({ -spec.STACK_DEPTH / 4, spec.STACK_DEPTH / 4 }) do
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
		Enum.Material.Wood,
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
	-- THE SOFFIT (the Designer's lodge spec, 2026-10-16, section 12): the porch roof's underside is
	-- the first thing a player sees walking up to the door, and it is a flat near-black slab (image
	-- 01). One board under it, in the ceiling's own colour, turns it into a lined roof.
	part(
		"PorchSoffit",
		Vector3.new(width + 3.2, 0.14, math.sqrt(run * run + drop * drop) + 0.8),
		CFrame.new(origin.X, (eaveY - 0.4 + postTop + 0.9) / 2 - 0.42, (eaveZ + frontZ) / 2)
			* CFrame.Angles(-math.atan2(drop, run), 0, 0),
		cfg.LODGE.CEILING_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	-- THE BENCH beside the door, on the west side.
	local benchX = origin.X - cfg.LODGE.DOOR.WIDTH / 2 - 4.4
	part(
		"PorchBench",
		Vector3.new(5.4, 0.45, 1.8),
		CFrame.new(benchX, floorY + 1.5, deckZ + spec.DEPTH / 4),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.Wood,
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
					-- 1.02 AND 0.92 AGAINST A 1.05 BILLET (the Designer's lodge spec, 2026-10-16,
					-- section 12): at 1.10 and 0.95 there was DAYLIGHT between every billet, which is
					-- image 01's complaint. At this pitch they touch.
					pileX - spec.WOOD_PER_ROW * 0.51 + (index - 0.5) * 1.02 + offset,
					floorY + 0.55 + (row - 1) * 0.92,
					deckZ + spec.DEPTH / 5
				) * CFrame.Angles(0, math.pi / 2, 0),
				-- THREE CLOSE TONES AND NOT TWO UNRELATED ONES, so the pile reads as split wood
				-- rather than as plastic tube.
				cfg.LODGE.FIREWOOD_TONES[(row + index) % 3 + 1],
				Enum.Material.Wood,
				false,
				folder
			)
			piece.Shape = Enum.PartType.Cylinder
		end
	end
	-- TWO RETAINING STAKES (spec 12): without them a stack of loose cylinders has no reason not to
	-- roll off the deck.
	for index, side in ipairs({ -1, 1 }) do
		local stake = part(
			string.format("WoodStake%d", index),
			Vector3.new(4.2, 0.22, 0.22),
			CFrame.new(pileX + side * (spec.WOOD_PER_ROW * 0.51 + 0.3), floorY + 2.1, deckZ + spec.DEPTH / 5)
				* CFrame.Angles(0, 0, math.pi / 2),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			folder
		)
		stake.Shape = Enum.PartType.Cylinder
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
-- THE PROMPT IS NOT HIS ANY MORE (task 195): it hangs on the COUNTER, in front of the clip that
-- stops a player vaulting it, because `CanQuery = false` turned out to be ignored while
-- `CanCollide` is true and a prompt behind a solid barrier is a shop nobody can open. See
-- `shopPrompt` below, which is built only when THIS function returns a body.
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
	--
	-- HOW HIGH, AND IT IS THE ENGINE'S OWN ANSWER SINCE TASK 195 (Karen: *"person not hanging"*).
	-- `Humanoid.HipHeight` is the distance from the ROOT PART'S BOTTOM to the ground it stands on,
	-- so the root's CENTRE belongs at `floorY + HipHeight + rootHalfHeight`. MEASURED in the live
	-- place: HipHeight 2.192 on a 2-stud root is 3.192, against the 3 that `KEEPER.ROOT_HEIGHT`
	-- guesses -- which is the 0.188 studs of floorboard Karen was looking through.
	--
	-- WHY NOT JUST MEASURE HIS LOWEST PART, which is what this did first and is why the figure
	-- above is known: the idle clip moves his legs, and a body seated by its own default pose sank
	-- 0.174 studs the moment the animation started (measured, the same place, the same session).
	-- `HipHeight` is a property of the rig and not of the frame it is in.
	--
	-- `ROOT_HEIGHT` IS THE FALLBACK, for a hand-built body with no HipHeight at all.
	local rootHalf = root.Size.Y / 2
	local lift = if man.HipHeight > 0 then man.HipHeight + rootHalf else keep.ROOT_HEIGHT
	local standAt = Vector3.new(counterAt.X, floorY + lift, counterAt.Z + keep.BEHIND_STUDS)
	body.Parent = shop
	body:PivotTo(CFrame.lookAt(standAt, standAt - Vector3.new(0, 0, 10)))

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
	local painted = 0
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("BodyColors") then
			(child :: any).HeadColor3 = keep.SKIN_COLOR
			painted += 1
		end
	end
	-- FOUND OR CREATED, which is `Body.paint`'s own rule and not a flourish: a rig that arrived
	-- without a `BodyColors` has nowhere to put a head colour, and the one place that is true is a
	-- hand-built fake -- which is exactly where a silent miss would never be noticed.
	if painted == 0 then
		local colours = Instance.new("BodyColors");
		(colours :: any).HeadColor3 = keep.SKIN_COLOR
		colours.Parent = body
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

	-- AND THE GUARD, WHICH ONLY EVER LIFTS (task 195). `HipHeight` above is the rule; this is the
	-- measurement that catches it being wrong -- a dressed body whose lowest part is still under
	-- the boards is pulled up until it is not. It cannot push him DOWN, because the pose it
	-- measures is the one before the idle clip runs and that pose is an upper bound on his soles,
	-- never the final word.
	--
	-- AFTER THE DRESSING, DELIBERATELY: `Body.dress` can replace limbs, and a figure measured
	-- before it is a figure measured on a body that no longer exists.
	--
	-- THE PART'S OWN BOX, PROJECTED -- the same expression `fitBetween` uses for a rotated antler --
	-- so a tilted foot is measured by where it really reaches and not by its centre.
	local lowest = math.huge
	for _, descendant in ipairs(body:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local piece = descendant :: BasePart
			local _, _, _, _, _, _, m10, m11, m12 = piece.CFrame:GetComponents()
			local reach = 0.5
				* (math.abs(m10) * piece.Size.X + math.abs(m11) * piece.Size.Y + math.abs(m12) * piece.Size.Z)
			lowest = math.min(lowest, piece.Position.Y - reach)
		end
	end
	if lowest < math.huge and lowest < floorY then
		body:PivotTo(body:GetPivot() + Vector3.new(0, floorY - lowest, 0))
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

-- THE PROMPT, ON THE COUNTER AND IN FRONT OF THE CLIP (task 195).
--
-- IT USED TO HANG ON THE KEEPER'S ROOT, and a measurement moved it: `CanQuery = false` is IGNORED
-- while `CanCollide` is true (four parts, one per combination, shot at with a ray in the live
-- place -- collide+noquery HIT; research note section 3.1). So the clip that stops a player
-- vaulting the counter also stops the prompt's `RequiresLineOfSight` ray: a ray from a customer's
-- head to the keeper's head came back *"blocked by CounterGuard"* at 1.5, 3 and 5 studs back from
-- the till, and a prompt behind that is a shop nobody can open.
--
-- A FULL-HEIGHT BARRIER AND A SIGHT LINE THROUGH IT CANNOT BOTH EXIST, so the prompt is on the
-- customer's side of the barrier: an attachment on the counter, over the till, `PROMPT_OUT_STUDS`
-- clear of the clip's own slab, with the keeper standing directly behind it. `Lobby.shopPrompt`
-- finds it by NAME anywhere under `Workspace.Lobby`, so nothing downstream changes.
--
-- IT IS BUILT ONLY WHEN THERE IS A KEEPER, which is task 181's rule unchanged: a "Press E" over an
-- empty counter is worse than no prompt at all.
--
-- Every property is a number in `Lobby.CONFIG.LODGE.KEEPER.PROMPT`, and ONE property set covers a
-- keyboard, a gamepad and a thumb.
--   ProximityPrompt  https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
local function shopPrompt(counter: BasePart, cfg, seams: Seams?): ProximityPrompt
	local keep = cfg.LODGE.KEEPER
	local at = Instance.new("Attachment")
	at.Name = "ShopPromptAt"
	at.Position = Vector3.new(
		0,
		cfg.LODGE.COUNTER.Y / 2 + 0.35 + keep.PROMPT_OVER_STUDS,
		-(cfg.LODGE.COUNTER.Z / 2 + keep.PROMPT_OUT_STUDS)
	)
	at.Parent = counter
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
	return prompt
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

-- THERE ARE NO DRAWN ANTLERS ANY MORE (task 196). Karen, 2026-10-16, looking at the lodge:
-- *"remove those fake antlers we will need real deer head with antlers and boar head"*, and asked
-- where the heads come from: *"we use our boar head and then add on a wall thats it in when we get
-- red stag we add also"*.
--
-- So the twelve roe plates, the two stags and the boar's tusk `Gewaff` -- every one of them a
-- bundle of cylinders aimed along a curve -- are gone, with `antlerPiece`, `antlerBeam`,
-- `antlerMount` and `boarMount`, and are archived whole in
-- `backups/2026-10-16_task-196_drawn-antlers.luau` (rule 7). What hangs on the wall now is the
-- GAME'S OWN BOAR, and the red stag's place is kept empty until the game has a red stag to put in
-- it: a trophy wall is a record of what has been shot, and a wall of drawn sticks is a claim about
-- animals this game does not have.
--
-- `shield` SURVIVES, because a plaque is a plaque: it is what the boar's head is mounted on.

-- A CARVED OAK SHIELD (the Designer's lodge spec, 2026-10-16, section 14). Six parts where there
-- were two.
--
-- Karen: *"boar head is good but background is bad this wood is bad"*. The head is unchanged; this
-- is everything behind it. A dark oak board with a ROUND TOP and a POINT -- the European form -- a
-- LIGHTER INNER PANEL standing 0.09 proud of it and leaving a 0.45 rim all round, and a BRASS PLATE
-- under the chin where a real one is engraved. Under Roblox's own lighting that 0.09 step reads as a
-- bevelled edge, which is a shadow line for no extra part.
--
-- THE ROUND TOP IS A CYLINDER TURNED ONTO z: `CFrame.Angles(0, pi/2, 0)` puts its circular face
-- toward the room, so its diameter is the board's width and its own length is the board's thickness.
-- `upright`'s turn is about Z and would stand it on edge.
--
-- IT ANSWERS WHERE THE HEAD GOES: the middle of the INNER PANEL, 0.09 proud of its face, so the
-- snout comes out of the lighter oak and not out of the rim.
local function shield(folder: Instance, name: string, face: CFrame, spec, cfg): CFrame
	local look = cfg.TROPHIES
	local box = look.SHIELD
	local width, body, point = spec.WIDTH, spec.BODY, spec.POINT
	local boardZ = -box.BOARD_THICK / 2
	part(
		string.format("%sBoard", name),
		Vector3.new(width, body, box.BOARD_THICK),
		face * CFrame.new(0, body * 0.026, boardZ),
		look.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	local crown = part(
		string.format("%sCrown", name),
		Vector3.new(box.BOARD_THICK, width, width),
		face * CFrame.new(0, body / 2 + width * 0.016, boardZ) * CFrame.Angles(0, math.pi / 2, 0),
		look.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	crown.Shape = Enum.PartType.Cylinder
	-- THE POINT AT THE BOTTOM, which is what makes a rectangle a shield.
	--
	-- A SQUARE TURNED FORTY-FIVE DEGREES, NOT A `WedgePart` (part 3c). The wedge was laid on its
	-- side: a `WedgePart`'s slope runs along its own +Z and the three rotations above stood it
	-- HORIZONTAL, so what hung under every plaque was a flat slab -- the *"loose LEDGE/shelf block
	-- under it that looks like a mistake"* the Director read off `B-trophy-wall-from-door.png`, four
	-- times over. A square rotated about the face's normal needs no guess about which way a wedge
	-- slopes: its lower half is a downward point `2 * point` wide and `point` deep, and its upper
	-- half is behind the board where nobody sees it.
	local side = point * math.sqrt(2)
	local tip = part(
		string.format("%sPoint", name),
		Vector3.new(side, side, box.BOARD_THICK),
		face * CFrame.new(0, -(body / 2) + body * 0.026, boardZ) * CFrame.Angles(0, 0, math.pi / 4),
		look.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	tip.CastShadow = false
	-- THE INNER PANEL: the same two shapes at the rim's inset, standing proud.
	local panelWidth = width - 2 * box.RIM_STUDS
	local panelZ = -(box.BOARD_THICK + box.PANEL_THICK / 2 + 0.06)
	part(
		string.format("%sFace", name),
		Vector3.new(panelWidth, body * 0.684, box.PANEL_THICK),
		face * CFrame.new(0, body * 0.184, panelZ),
		look.PANEL_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	local panelCrown = part(
		string.format("%sFaceCrown", name),
		Vector3.new(box.PANEL_THICK, panelWidth, panelWidth),
		face * CFrame.new(0, body / 2 + width * 0.016, panelZ) * CFrame.Angles(0, math.pi / 2, 0),
		look.PANEL_COLOR,
		Enum.Material.Wood,
		false,
		folder
	)
	panelCrown.Shape = Enum.PartType.Cylinder
	-- THE BRASS PLATE, on the dark board below the panel, on a flat surface -- which is where a real
	-- one is. It carries the animal's name on a `SurfaceGui`, and a `SurfaceGui` is not a part.
	local plate = part(
		string.format("%sPlate", name),
		Vector3.new(width * 0.47, body * 0.21, box.PLATE_THICK),
		face * CFrame.new(0, -(body * 0.326), -(box.BOARD_THICK + box.PLATE_THICK / 2 + 0.02)),
		look.BRASS_COLOR,
		Enum.Material.Metal,
		false,
		folder
	)
	plate.Reflectance = 0.15
	if spec.LABEL ~= nil then
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Engraving"
		surface.Face = Enum.NormalId.Front
		surface.CanvasSize = Vector2.new(240, 60)
		surface.Parent = plate
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(36, 27, 18)
		text.Text = spec.LABEL
		text.Parent = surface
	end
	-- WHERE THE HEAD MOUNTS: the middle of the inner panel, 0.09 proud of its face.
	return face * CFrame.new(0, body * 0.184, panelZ - box.PANEL_THICK / 2 - 0.09)
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

-- SLIDE A WHOLE MOUNT UNTIL IT IS INSIDE A BAND, or say it cannot be. Down from the top first and
-- then up off the bottom, so a mount taller than its band ends resting on the floor rather than
-- through the ceiling -- the better of the two wrong answers.
--
-- IT IS A FUNCTION BECAUSE IT HAS THREE CALLERS NOW (round 3): the twelve wall mounts, the antlers
-- over the door and the stag on the gable. The last two were hung on arithmetic instead, and the
-- door's one was driven straight through the roof's south slope -- the same class of mistake as the
-- porch roof, and for the same reason: a 44-degree eave is already lower at the wall than the wall
-- top is.
local function fitBetween(folder: Instance, low: number, high: number): number
	local lowest, highest = math.huge, -math.huge
	for _, piece in ipairs(folder:GetChildren()) do
		if piece:IsA("BasePart") then
			local bottom, top = spanY(piece :: BasePart)
			lowest, highest = math.min(lowest, bottom), math.max(highest, top)
		end
	end
	if lowest == math.huge then
		return 0
	end
	local shift = math.min(0, high - highest)
	shift += math.max(0, low - (lowest + shift))
	if math.abs(shift) > 1e-4 then
		for _, piece in ipairs(folder:GetChildren()) do
			if piece:IsA("BasePart") then
				local moved = piece :: BasePart
				moved.CFrame = moved.CFrame + Vector3.new(0, shift, 0)
			end
		end
	end
	return shift
end

-- THE BOAR'S HEAD ON THE WALL (task 196). Karen: *"we use our boar head and then add on a wall
-- thats it"*.
--
-- IT IS THE GAME'S OWN ANIMAL AND NOT A DRAWING OF ONE, and not an upload either: the bought,
-- prepared boar (`ServerStorage.Assets`'s `boar.male`, the same template every animal in the drive
-- wears) is cloned, pointed out of a plaque, and the REST OF IT IS PUT INSIDE THE STONE. A skinned
-- mesh cannot be cut into pieces -- `docs/PROJECT_CONTEXT.md` names that as one of the things that
-- killed the previous project -- so there is no "head" to clone: there is a whole boar, 5.5 studs
-- of it, and the only honest way to show a head is to hide the other four.
--
-- WHERE IT HANGS IS WHAT MAKES THAT POSSIBLE: the CHIMNEY BREAST, which stands `FIREPLACE.DEPTH`
-- (3.2) studs proud of the west wall and is solid stone from the mantel to the ceiling, with the
-- wall logs and the chimney stack behind it. The body goes back into that stone and TILTS UP, so
-- what is behind the plaque is inside a part that is opaque from every side -- inside the room and
-- outside the lodge. The alternative, a box standing four studs out from a flat wall, is a cupboard
-- with a boar in it.
--
-- THE NOSE POINTS SLIGHTLY DOWN, which is what a shoulder mount does: it looks at the room rather
-- than over it.
--
-- WITH NO TEMPLATE IT HANGS THE PLAQUE AND NOTHING ELSE, which is the DEV place and every spec: a
-- lodge with no asset pipeline has a bare board on the chimney, not a crash.
local function boarTrophy(
	folder: Instance,
	name: string,
	face: CFrame,
	spec,
	cfg,
	template: Instance?,
	low: number,
	high: number
)
	local front = shield(folder, name, face, spec, cfg)
	-- THE PLAQUE IS FITTED FIRST AND THE HEAD IS HUNG OFF WHERE IT ENDED UP. `fitBetween` slides
	-- every BasePart in the folder until the board is inside the room; the head is a MODEL and the
	-- clamp cannot see it, which is deliberate -- most of the animal is inside the stonework on
	-- purpose, and a clamp that could see it would drag the head out into the room to rescue the
	-- hidden half.
	front += Vector3.new(0, fitBetween(folder, low, high), 0)
	if template == nil or not template:IsA("Model") then
		stats.fallbacks += 1
		return
	end
	local head = (template :: Model):Clone()
	head.Name = string.format("%sHead", name)
	stats.strippedScripts += scriptsIn(head)
	-- THE WHOLE ANIMAL, MEASURED, so the arithmetic below is about the model that actually arrived
	-- rather than about a number in a manifest.
	local _, size = head:GetBoundingBox()
	local tilt = math.rad(spec.TILT_DEGREES)
	local aim = front * CFrame.Angles(-tilt, 0, 0)
	-- HOW FAR THE BOX'S CENTRE SITS BEHIND THE PLAQUE: half the animal's length, less the muzzle we
	-- want in the room. Along the body's OWN axis, so the tilt moves it back and up together.
	local back = size.Z / 2 - spec.SNOUT_STUDS
	head:PivotTo(aim)
	local box = head:GetBoundingBox()
	-- CENTRED ON THE POINT WE MEAN, the same correction `cloneInstance` makes and for the same
	-- reason: a model's pivot is its bounding-box centre only while nobody has set a PrimaryPart.
	local target = (aim * CFrame.new(0, 0, back)).Position
	head:PivotTo(head:GetPivot() + (target - box.Position))
	-- NO TROTTERS UNDER THE PLAQUE (part 3c). The mount is a whole animal with most of it inside the
	-- wall, and on `B-trophy-wall-from-door.png` its FEET poked out below every board -- measured
	-- afterwards at 0.05 studs on the boars and 0.13 on the sows, which at that distance is four
	-- pale specks under a brass plate. The board's bottom is arithmetic off `front` (`shield` hangs
	-- the board at `body * 0.026` under a face that is `body * 0.184` under the mount point), so the
	-- animal is simply lifted until its lowest part is 0.12 inside the board.
	local boardBottom = front.Position.Y - spec.BODY * 0.658
	local seated, extent = head:GetBoundingBox()
	local under = (boardBottom + 0.12) - (seated.Position.Y - extent.Y / 2)
	if under > 0 then
		head:PivotTo(head:GetPivot() + Vector3.new(0, under, 0))
	end
	for _, descendant in ipairs(head:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local piece = descendant :: BasePart
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			stats.parts += 1
		end
	end
	head.Parent = folder
	stats.models += 1
end

local function trophies(inside: Instance, room: Room, cfg, assets: ((string) -> Instance?)?)
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
		-- ONE KIND OF MOUNT SINCE TASK 196, and it is a real animal (see `boarTrophy`). The row's
		-- `kind` still decides, because the red stag gets a row of its own the day the game has one
		-- and it will not be a boar.
		boarTrophy(
			one,
			name,
			face,
			kind,
			cfg,
			-- THE ROW ASKS FOR ITS OWN ANIMAL (spec 14c): `"boar"` or `"sow"`, which the composition
			-- root translates into a template. A literal `"boar"` here is what made every mount a
			-- male.
			if assets ~= nil then assets(kind.ASSET) else nil,
			room.centre.Y + 0.3,
			room.centre.Y + room.height - 0.3
		)
	end

	-- THE BOARDED BACK STORE AND THE TWO SCONCES WENT WITH THE NORTH WALL (part 3d). The store was
	-- the depth four boar rumps needed behind them -- measured at 1.52 studs proud of the outside
	-- face -- and the sconces were lit for four heads. The one mount left is the capital boar over
	-- the fire, which sits 6.25 studs inside the chimney stonework and never needed either.
	-- Archived: `backups/2026-10-16_task-196_table-and-north-trophies.txt`.

	-- THE RED STAG'S PLACE IS A CONFIG ROW AND NOTHING ELSE SINCE PART 3E. Two iron pegs were fixed
	-- where his shield would hang, so that the gap would read as KEPT rather than forgotten; on an
	-- otherwise bare log wall they read as two stray dots, which the Director saw in
	-- `K-room-from-the-door.png`. `TROPHIES.STAG_PLACE` keeps the measurements for the day he
	-- exists -- where he hangs and how much wall is reserved -- and builds nothing.
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
	-- TWO CORBELS UNDER THE MANTEL'S ENDS (spec 10): it overhangs the breast by half a stud each
	-- side and floats there (image 19). A mantel rests on something.
	for index, dz in ipairs({ -4.5, 4.5 }) do
		part(
			string.format("FireplaceCorbel%d", index),
			Vector3.new(0.9, 0.9, 1.2),
			CFrame.new(wallX + 1.6, floorY + spec.OPENING_HEIGHT - 0.35, z + dz),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			inside
		)
	end
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
-- A LANTERN WITH A FRAME (spec 11). Image 30: a glowing white box with a dark lid on a wire -- no
-- frame, no base, nothing holding it at the ceiling. Four corner posts, a base, and a rose where the
-- chain lands turn it into a made object, and the glass shrinks so the posts show against it.
local function lantern(inside: Instance, name: string, at: Vector3, ceilingY: number, cfg)
	local box = part(
		name,
		Vector3.new(0.7, 0.95, 0.7),
		CFrame.new(at),
		cfg.LODGE.LANTERN.GLASS_COLOR,
		Enum.Material.Neon,
		false,
		inside
	)
	box.Transparency = 0.42
	local iron = cfg.LODGE.IRON_COLOR
	part(
		string.format("%sCap", name),
		Vector3.new(1.15, 0.3, 1.15),
		CFrame.new(at + Vector3.new(0, 0.62, 0)),
		iron,
		Enum.Material.Metal,
		false,
		inside
	)
	part(
		string.format("%sBase", name),
		Vector3.new(1.15, 0.22, 1.15),
		CFrame.new(at + Vector3.new(0, -0.58, 0)),
		iron,
		Enum.Material.Metal,
		false,
		inside
	)
	for index, corner in ipairs({ Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1) }) do
		part(
			string.format("%sPost%d", name, index),
			Vector3.new(0.1, 1.05, 0.1),
			CFrame.new(at + Vector3.new(corner.X * 0.4, 0, corner.Y * 0.4)),
			iron,
			Enum.Material.Metal,
			false,
			inside
		)
	end
	-- THE ROSE AT THE CEILING, where the chain lands: a lamp hanging off nothing is the complaint.
	if ceilingY > at.Y then
		part(
			string.format("%sRose", name),
			Vector3.new(0.7, 0.18, 0.7),
			CFrame.new(at.X, ceilingY - 0.09, at.Z),
			iron,
			Enum.Material.Metal,
			false,
			inside
		)
	end
	local chain = part(
		string.format("%sChain", name),
		Vector3.new(ceilingY - at.Y - 0.62, 0.14, 0.14),
		CFrame.new(at + Vector3.new(0, (ceilingY - at.Y + 0.62) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		cfg.LODGE.IRON_COLOR,
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

-- ONE AMMO BOX ON A SHELF: a cardboard carton with a coloured label, the same two colours the
-- shop's own picture of a box of shells uses.
local function ammoBox(inside: Instance, name: string, face: CFrame, cfg)
	local box = cfg.LODGE.RACK.AMMO_BOX
	part(
		string.format("%sBox", name),
		box.SIZE,
		face,
		cfg.LODGE.RACK.CARDBOARD_COLOR,
		Enum.Material.Fabric,
		false,
		inside
	)
	part(
		string.format("%sLabel", name),
		Vector3.new(box.SIZE.X * 0.7, box.SIZE.Y * 0.45, 0.04),
		face * CFrame.new(0, 0, -box.SIZE.Z / 2 - 0.02),
		cfg.LODGE.RACK.LABEL_COLOR,
		Enum.Material.SmoothPlastic,
		false,
		inside
	)
end

-- THE WALL OF GUNS BEHIND THE COUNTER (task 196). A board, a peg pair per gun, the guns themselves
-- laid horizontally across it, and a shelf under them with two boxes of shells on it.
--
-- EVERY GUN IS A CLONE OF THE REAL ONE. `assets("shotgun")` and `assets("rifle")` are the
-- composition root's answer to *"what does the gun the player carries look like"* -- a Model built
-- by `Weapon.Hardware`, the one builder of guns in this game -- so this module never learns what a
-- weapon is, exactly as it never learns what an outfit is (`seams.dress`). A missing template is not
-- an error: the pegs are there and the gun is not, which is the same rule every free-model clone in
-- this file follows.
--
-- HOW A GUN IS LAID ON PEGS: its own length is its Z (`HANDLE_SIZE.Z` is 4.4) and its up is its Y,
-- so a quarter turn about Y lays it along the wall with its side to the room. The pegs are set to
-- the gun's own length rather than to a number typed here.
local function gunRack(inside: Instance, room: Room, cfg, counterAt: Vector3, assets: ((string) -> Instance?)?)
	local rack = cfg.LODGE.RACK
	-- ON THE NORTH WALL, CENTRED ON THE COUNTER, so it is behind the man and not behind the door.
	-- `yaw = 0` looks south -- into the room -- which is `shield`'s own convention and the one every
	-- trophy row uses.
	local face =
		CFrame.new(counterAt.X + rack.ALONG_STUDS, room.centre.Y + rack.HEIGHT_STUDS, room.centre.Z + room.halfZ)
	part(
		"GunRackBoard",
		Vector3.new(rack.WIDTH, rack.HEIGHT, rack.BOARD_THICK),
		face * CFrame.new(0, 0, -rack.BOARD_THICK / 2),
		cfg.TROPHIES.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	local front = face * CFrame.new(0, 0, -rack.BOARD_THICK)
	-- THE SHELF, under the board, with its two boxes standing ON it rather than in it.
	local shelf = part(
		"GunRackShelf",
		Vector3.new(rack.WIDTH, rack.SHELF_THICK, rack.SHELF_DEPTH),
		front * CFrame.new(0, -rack.HEIGHT / 2 - rack.SHELF_THICK / 2, -rack.SHELF_DEPTH / 2),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	local boxSize = rack.AMMO_BOX.SIZE
	for index, along in ipairs(rack.AMMO_BOX.ALONG) do
		ammoBox(
			inside,
			string.format("Ammo%d", index),
			CFrame.new(
				shelf.Position.X + along,
				shelf.Position.Y + rack.SHELF_THICK / 2 + boxSize.Y / 2,
				shelf.Position.Z
			),
			cfg
		)
	end
	-- THE GUNS, STACKED UP THE BOARD, the shotgun and the rifle alternating.
	for index = 1, rack.GUNS do
		local dy = rack.HEIGHT / 2 - rack.FIRST_GUN_DROP - (index - 1) * rack.GUN_GAP
		local template = if assets ~= nil then assets(if index % 2 == 1 then "shotgun" else "rifle") else nil
		local gun = if template ~= nil and template:IsA("Model") then (template :: Model):Clone() else nil
		local span = rack.PEG_SPAN
		if gun ~= nil then
			stats.strippedScripts += scriptsIn(gun)
			local _, size = gun:GetBoundingBox()
			span = math.max(size.Z * 0.5, 1)
			-- A QUARTER TURN LAYS IT ALONG THE WALL, and then its box is centred on the pegs -- the
			-- same correction `cloneInstance` makes, because a Tool's Handle is its pivot and that is
			-- not the middle of the gun.
			local aim = front * CFrame.new(0, dy, -rack.GUN_OUT) * CFrame.Angles(0, math.pi / 2, 0)
			gun:PivotTo(aim)
			local box = gun:GetBoundingBox()
			gun:PivotTo(gun:GetPivot() + (aim.Position - box.Position))
			gun.Name = string.format("RackGun%d", index)
			for _, descendant in ipairs(gun:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					piece.Anchored = true
					piece.CanCollide = false
					piece.CanQuery = false
					piece.CanTouch = false
					stats.parts += 1
				end
			end
			gun.Parent = inside
			stats.models += 1
		else
			stats.fallbacks += 1
		end
		for peg, side in ipairs({ -1, 1 }) do
			local hook = part(
				string.format("GunRackPeg%d_%d", index, peg),
				Vector3.new(rack.PEG_STUDS, rack.PEG_THICK, rack.PEG_THICK),
				-- THE PEG BEGINS AT THE BOARD'S FACE: half its own length out, never its whole length
				-- (task 195's measured defect -- two pegs that began 0.05 studs clear of the board).
				front
					* CFrame.new(side * span, dy - rack.PEG_DROP, -rack.PEG_STUDS / 2)
					* CFrame.Angles(0, math.pi / 2, 0),
				cfg.LODGE.TIMBER_COLOR,
				Enum.Material.Wood,
				false,
				inside
			)
			hook.Shape = Enum.PartType.Cylinder
		end
	end
end

-- THE WARM INSIDE: floorboards, a beamed ceiling, the fireplace, a heavy table with its benches,
-- three lanterns, a gun rack, the shop counter -- and, since task 181, the man standing behind it.
-- Nothing here is animated per frame and nothing is written per frame: the keeper's idle is played
-- once, at build, and his head is turned by the owner's own 10 Hz scan.
-- THE SILL PLATE AND THE WALL PLATE (the Designer's lodge spec, 2026-10-16, section 9). Images 18,
-- 22 and 23: a round log meets a flat floor in a SCALLOPED line, and the top course is simply cut
-- off by the ceiling boards. A real log building has a flat `Schwelle` at the bottom and a wall
-- plate at the top; both close the joint, and both are four parts.
--
-- EVERY JOIN IN THIS SPEC OVERLAPS AND IS NEVER FLUSH: the wall plate's top (11.90 + 0.40 = 12.30)
-- laps the ceiling boards' underside (12.20) by 0.10, because two coplanar faces are what
-- z-fighting is made of.
local function plates(inside: Instance, room: Room, cfg)
	local timber = cfg.LODGE.TIMBER_COLOR
	local alongX = room.halfX * 2 - 3.8
	local alongZ = room.halfZ * 2 - 3.8
	for _, row in ipairs({
		{ name = "SillPlateS", size = Vector3.new(alongX, 0.5, 1), at = Vector3.new(0, 0.25, -(room.halfZ - 0.5)) },
		{ name = "SillPlateN", size = Vector3.new(alongX, 0.5, 1), at = Vector3.new(0, 0.25, room.halfZ - 0.5) },
		{ name = "SillPlateW", size = Vector3.new(1, 0.5, alongZ), at = Vector3.new(-(room.halfX - 0.5), 0.25, 0) },
		{ name = "SillPlateE", size = Vector3.new(1, 0.5, alongZ), at = Vector3.new(room.halfX - 0.5, 0.25, 0) },
		{
			name = "WallPlateS",
			size = Vector3.new(alongX, 0.8, 1),
			at = Vector3.new(0, room.height - 0.7, -(room.halfZ - 0.5)),
		},
		{
			name = "WallPlateN",
			size = Vector3.new(alongX, 0.8, 1),
			at = Vector3.new(0, room.height - 0.7, room.halfZ - 0.5),
		},
		{
			name = "WallPlateW",
			size = Vector3.new(1, 0.8, alongZ),
			at = Vector3.new(-(room.halfX - 0.5), room.height - 0.7, 0),
		},
		{
			name = "WallPlateE",
			size = Vector3.new(1, 0.8, alongZ),
			at = Vector3.new(room.halfX - 0.5, room.height - 0.7, 0),
		},
	}) do
		part(row.name, row.size, CFrame.new(room.centre + row.at), timber, Enum.Material.Wood, false, inside)
	end
end

local function interior(folder: Instance, room: Room, cfg, seams: Seams?)
	-- WHAT THE COMPOSITION ROOT CAN HAND US: the boar for the trophy, and the two guns for the rack
	-- behind the counter (task 196). nil everywhere else, which is the DEV place and every spec.
	local assets = (seams or {}).assets
	local origin = room.centre
	local inside = Instance.new("Folder")
	inside.Name = "Inside"
	inside.Parent = folder
	local ceilingY = origin.Y + room.height

	-- THE PLATES FIRST (spec 9), so the fireplace breast and the counter are built OVER them and the
	-- west run disappears behind the stone where it should.
	plates(inside, room, cfg)

	-- THE BEAMED CEILING. Boards first, then the beams under them, which is the order they are built
	-- in and the order they read in.
	part(
		"CeilingBoards",
		Vector3.new(room.halfX * 2, 0.4, room.halfZ * 2),
		CFrame.new(origin.X, ceilingY - 0.2, origin.Z),
		cfg.LODGE.CEILING_COLOR,
		Enum.Material.Wood,
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

	-- NO TABLE AND NO BENCHES SINCE TASK 196 PART 3D. KAREN, 2026-10-16: *"remove table and all
	-- boar heads only keep one where is on fireplace"*. The two benches go WITH the table and not
	-- after it, because a bench facing nothing in the middle of an empty room reads as a leftover
	-- rather than as furniture -- they were built from the table's own offset and size, and they
	-- had no other reason to stand where they stood. Nothing replaces them: what goes in that floor
	-- is Karen's to decide. Archived: `backups/2026-10-16_task-196_table-and-north-trophies.txt`.

	-- THE RUG IN FRONT OF THE HEARTH (task 195). Its BOTTOM is the floor's top, which is the whole
	-- of "a rug does not float and does not z-fight": `origin.Y + THICK / 2`, never `origin.Y`.
	local rug = cfg.LODGE.RUG
	part(
		"Rug",
		Vector3.new(rug.SIZE.X, rug.THICK, rug.SIZE.Y),
		CFrame.new(origin.X + rug.OFFSET.X, origin.Y + rug.THICK / 2, origin.Z + rug.OFFSET.Y),
		rug.COLOR,
		rug.MATERIAL,
		false,
		inside
	)

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
	local counterPart = part(
		"Counter",
		cfg.LODGE.COUNTER,
		CFrame.new(counterAt),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.Wood,
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
	-- THE SERVICE SIDE, CLOSED (task 195). Karen: *"you can't go over the table"*. Before this the
	-- counter was 12 studs of a 32.4-stud room with a 3.2-stud gap at its east end and seventeen at
	-- its west, and a 3.55-stud top against a default `JumpHeight`.
	--
	-- VISIBLE TIMBER FIRST, THE CLIP ONLY ABOVE IT -- Valve's rule for a clip brush, which is that
	-- the invisible surface must lie on something the eye can see (research note section 4). The
	-- WING runs from the counter's east end to the east wall and the RETURN from its west end to the
	-- north wall, both at the counter's own height and in its own timber, so the keeper is in a
	-- three-sided bay; the CLIPS stand from the counter top to the ceiling, flush with the bay's two
	-- open faces, so the only way in is over a wall that is not there.
	local service = cfg.LODGE.SERVICE
	local counterFrontZ = counterAt.Z - cfg.LODGE.COUNTER.Z / 2
	local counterWestX = counterAt.X - cfg.LODGE.COUNTER.X / 2
	local counterEastX = counterAt.X + cfg.LODGE.COUNTER.X / 2
	local eastWallX = origin.X + room.halfX
	local northWallZ = origin.Z + room.halfZ
	local returnWestX = counterWestX - service.RETURN_WIDTH
	-- WHERE THE CLIPS BEGIN: the top of the SOLID counter, not the top of the cosmetic slab above
	-- it. The 0.35-stud `CounterTop` does not collide (nothing cosmetic in this lodge does), so a
	-- clip that started above it would leave a 0.35-stud band with no solid in it -- narrower than
	-- a body, but a hole in a claim that says "sealed from the floor to the ceiling", and the spec
	-- samples the plane rather than taking the claim's word.
	local counterTopY = origin.Y + cfg.LODGE.COUNTER.Y
	-- ...and the cosmetic slab's own top, which is only used to SIT the two matching slabs.
	local capTopY = counterTopY + 0.35
	-- THE WING. Nothing is built when the counter already reaches the wall (the clamp above can put
	-- it there in a narrow room), because a zero-width part is a part nobody can explain.
	local wingWidth = eastWallX - counterEastX
	if wingWidth > 0.05 then
		part(
			"CounterWing",
			Vector3.new(wingWidth, cfg.LODGE.COUNTER.Y, cfg.LODGE.COUNTER.Z),
			CFrame.new((counterEastX + eastWallX) / 2, origin.Y + cfg.LODGE.COUNTER.Y / 2, counterAt.Z),
			cfg.LODGE.FURNITURE_COLOR,
			Enum.Material.Wood,
			true,
			shop
		)
		-- ITS TOP STARTS WHERE `CounterTop`'S OVERHANG ENDS, so the two slabs meet rather than
		-- cross, and it stops AT the wall rather than in it.
		local capFrom = counterEastX + 0.4
		part(
			"CounterWingTop",
			Vector3.new(eastWallX - capFrom, 0.35, cfg.LODGE.COUNTER.Z + 0.8),
			CFrame.new((capFrom + eastWallX) / 2, capTopY - 0.175, counterAt.Z),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			shop
		)
	end
	-- THE RETURN, from the counter's west end back to the north wall.
	local returnLength = northWallZ - counterFrontZ
	part(
		"CounterReturn",
		Vector3.new(service.RETURN_WIDTH, cfg.LODGE.COUNTER.Y, returnLength),
		CFrame.new(
			returnWestX + service.RETURN_WIDTH / 2,
			origin.Y + cfg.LODGE.COUNTER.Y / 2,
			(counterFrontZ + northWallZ) / 2
		),
		cfg.LODGE.FURNITURE_COLOR,
		Enum.Material.Wood,
		true,
		shop
	)
	part(
		"CounterReturnTop",
		Vector3.new(service.RETURN_WIDTH + 0.4, 0.35, returnLength),
		CFrame.new(
			returnWestX - 0.4 + (service.RETURN_WIDTH + 0.4) / 2,
			capTopY - 0.175,
			(counterFrontZ + northWallZ) / 2
		),
		cfg.LODGE.TIMBER_COLOR,
		Enum.Material.Wood,
		false,
		shop
	)
	-- THE TWO CLIPS. Each one's visible face is exactly a counter face: the front clip's north side
	-- is the counter's customer face, the west clip's east side is the return's west face.
	clip(
		"CounterGuard",
		Vector3.new(eastWallX - returnWestX + service.CLIP_THICK, ceilingY - counterTopY, service.CLIP_THICK),
		CFrame.new(
			(returnWestX - service.CLIP_THICK + eastWallX) / 2,
			(counterTopY + ceilingY) / 2,
			counterFrontZ - service.CLIP_THICK / 2
		),
		shop
	)
	clip(
		"CounterGuardWest",
		Vector3.new(service.CLIP_THICK, ceilingY - counterTopY, returnLength),
		CFrame.new(returnWestX - service.CLIP_THICK / 2, (counterTopY + ceilingY) / 2, (counterFrontZ + northWallZ) / 2),
		shop
	)

	-- A `SurfaceGui`'s `Front` face is the part's own -Z, which is also its LookVector -- so a board
	-- left unrotated on the north wall already reads into the room, and the half turn this had put
	-- the word SHOP face down in the logs. Photographed, not reasoned about.
	--
	-- `- 0.3` PUT ITS BACK 0.15 STUDS OFF THE LOGS (task 195, measured): half the board's own
	-- thickness is the whole offset a flush board needs, and 0.15 of air is a sign that hangs.
	sign(
		"ShopSign",
		Vector3.new(8, 2.2, 0.3),
		-- 9.4 AND NOT 7.4 (spec 10): at 7.4 the sign crossed the rack board. It now spans y
		-- 8.30..10.50, clearing the board's top by 1.00 and the ceiling beams by 0.80.
		CFrame.new(counterAt.X, origin.Y + math.min(9.4, room.height - 1.6), origin.Z + room.halfZ - 0.15),
		cfg.LODGE.SIGN_TEXT,
		shop
	)
	-- THE COUNTER'S FRONT, THE SURFACE EVERY PLAYER LOOKS AT LONGEST (spec 10, image 24): three
	-- vertical stiles on the customer's side, which is what turns a plain slab into joinery.
	for index, dx in ipairs({ -4.2, 0, 4.2 }) do
		part(
			string.format("CounterStile%d", index),
			Vector3.new(0.45, 2.4, 0.12),
			CFrame.new(counterAt.X + dx, origin.Y + 1.4, counterAt.Z - cfg.LODGE.COUNTER.Z / 2 - 0.06),
			cfg.LODGE.TIMBER_COLOR,
			Enum.Material.Wood,
			false,
			shop
		)
	end

	-- THE MAN BEHIND IT (task 181). `origin.Y` is the floor the counter stands on, which is what he
	-- stands on too -- the one number, read in one place. HIS prompt goes on the counter in front of
	-- him (task 195) and only when he is really there.
	if shopkeeper(shop, counterAt, origin.Y, cfg, seams) ~= nil then
		shopPrompt(counterPart, cfg, seams)
	end

	-- THE GUN RACK IS BEHIND THE SELLER NOW, AND THE GUNS ON IT ARE THE GAME'S OWN (task 196).
	-- Karen, 2026-10-16: *"behind the shoper shotguns on wall rifles on wall ect"*.
	--
	-- It used to hang on the WEST wall with two guns DRAWN on it -- a dark cylinder for a barrel and
	-- a brown box for a stock, which is exactly the kind of thing she has been removing all day. The
	-- board, its pegs and the two drawn guns are archived in
	-- `backups/2026-10-16_task-196_drawn-gun-rack.luau` (rule 7).
	--
	-- WHAT HANGS ON IT NOW IS `Weapon.Hardware`'s OWN OUTPUT -- the shotgun and the rifle the player
	-- carries, built by the one builder that builds them and handed in by the composition root as a
	-- template. So the wall behind the counter shows the things the counter sells, and the day the
	-- gun changes the wall changes with it. Scenery, every one of them: anchored, `CanCollide`,
	-- `CanQuery` and `CanTouch` all false, no Tool, nothing to pick up.
	gunRack(inside, room, cfg, counterAt, assets)

	trophies(inside, room, cfg, assets)
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
		-- 1.2 NARROWER THAN THE FOOTPRINT (spec 6): the slab's cut edge then dies 1.2 studs inside
		-- the logs' outer face instead of showing as a pale board over the plinth (image 05).
		Vector3.new(size.X - 1.2, cfg.LODGE.FLOOR_THICK, size.Z - 1.2),
		CFrame.new(origin.X, floorY - cfg.LODGE.FLOOR_THICK / 2, origin.Z),
		cfg.LODGE.FLOOR_COLOR,
		Enum.Material.Wood,
		true,
		folder
	)

	-- THE OPENINGS, PER WALL, AND THEY ARE THE SAME TABLE THE WINDOWS ARE HUNG FROM. One list, read
	-- twice -- once to cut the logs and once to dress the hole -- so a window can never be fitted to
	-- a wall that was not cut for it.
	local holes: { [string]: { Opening } } = { south = {}, north = {}, west = {}, east = {} }
	local doorBottom, doorTop = snapOpening(floorY, floorY, floorY + cfg.LODGE.DOOR.HEIGHT, d)
	table.insert(holes.south, {
		along = origin.X,
		width = cfg.LODGE.DOOR.WIDTH,
		bottom = doorBottom,
		top = doorTop,
	})
	local win = cfg.LODGE.WINDOW
	local winBottom, winTop = snapOpening(floorY, floorY + win.SILL_STUDS, floorY + win.SILL_STUDS + win.HEIGHT, d)
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
			bottom = winBottom,
			top = winTop,
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
		local y = (winBottom + winTop) / 2
		-- OUTWARD, ON ALL FOUR WALLS, and the four numbers below are the only place that is decided.
		-- A CFrame's LookVector is its own -Z, so `R_y(theta) * (0, 0, -1) = (-sin, 0, -cos)`: 0 looks
		-- SOUTH, pi NORTH, pi/2 WEST and -pi/2 EAST. Round 2, finding 1: south and north were the
		-- other way round, so a sill that is 1.35 studs along the LookVector stood INSIDE the room on
		-- the front elevation -- no sill and no shadow line on the wall Karen walks out of.
		local at, yaw
		if row.wall == "south" then
			at, yaw = Vector3.new(origin.X + row.along, y, origin.Z - halfZ + d / 2), 0
		elseif row.wall == "north" then
			at, yaw = Vector3.new(origin.X + row.along, y, origin.Z + halfZ - d / 2), math.pi
		elseif row.wall == "west" then
			at, yaw = Vector3.new(origin.X - halfX + d / 2, y, origin.Z + row.along), math.pi / 2
		else
			at, yaw = Vector3.new(origin.X + halfX - d / 2, y, origin.Z + row.along), -math.pi / 2
		end
		windowUnit(
			folder,
			string.format("%d", index),
			CFrame.new(at) * CFrame.Angles(0, yaw, 0),
			winTop - winBottom,
			cfg
		)
	end

	doorway(folder, origin, floorY, doorTop - doorBottom, cfg)
	roof(folder, origin, wallTop, cfg)
	chimney(folder, origin, cfg)

	-- NOTHING HANGS OUTSIDE ANY MORE (task 196). Karen, 2026-10-16: *"remove those fake antlers"*.
	-- The small mount over the door and the big stag on the east gable were the same drawn sticks as
	-- the ones inside, measured into their bands by `fitBetween` -- and a measurement cannot make a
	-- bundle of cylinders look like an animal. Both are archived in
	-- `backups/2026-10-16_task-196_drawn-antlers.luau` (rule 7) with the band arithmetic that got
	-- them clear of the roof, which is the half of that work worth keeping: the day a REAL stag head
	-- hangs on the east gable, `underEave` and `GABLE_MOUNT_STUDS` are where it goes.

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
		elseif skin == "light" and not Build.isTruckLamp(piece.Name, piece.Material, piece.Size, cfg) then
			-- **A "LIGHT" TOO BIG TO BE A LAMP IS A PROP** (task 243). `truckSkinOf` calls anything
			-- `Neon` or named "light" a light, which is right for the paint rule it was written for;
			-- `isTruckLamp` adds the SIZE, which is what stops `truckRig` hanging a SpotLight inside
			-- the chassis. Between the two there was a gap, and Karen photographed it: a 6.74-stud
			-- `Neon` bar at 255,89,89 on the rear quarter that neither the painter nor the rig
			-- touched. It is painted the model's own near-black trim, in the body's own material, so
			-- it stops glowing as well as stops being pink. The six real lamps are small and are
			-- `truckRig`'s -- this branch cannot reach them.
			piece.Color = spec.TRIM
			piece.Material = spec.BODY_MATERIAL
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
-- WHAT A THING IS BEING SETTLED AS. A truck sits ON the ground on four wheels and must never sink
-- into it; a tree is PLANTED, and its root claws have to go UNDER. One settler, two plans (lesson
-- L-031, 2026-10-16: *"one settler, not more per-task arithmetic"*), so the sampling, the pcall
-- discipline and the measured-not-computed return are written once.
export type SettlePlan = {
	-- THE CONTACT POINTS, when the caller knows better than `contactsOf`. A tree's contacts are its
	-- footprint, and their `bottom` is NOT the model's lowest point: see `treeContacts`.
	contacts: { { x: number, z: number, bottom: number } }?,
	-- TILT TO THE SLOPE? A truck does. A tree does not: a birch leaning with the hill is a birch
	-- that looks pushed over.
	tilt: boolean?,
	-- SETTLE TO THE LOWEST GROUND UNDER IT RATHER THAN THE HIGHEST. A truck lifts until NO wheel is
	-- buried, which is `max`. A tree sinks until NO contact is in the air, which is `min` -- the
	-- roots on the high side go into the bank, and that is the whole point.
	toLowest: boolean?,
	-- AND THEN A LITTLE FURTHER, so the junction is under the surface rather than exactly on it.
	sink: number?,
	-- A CONTACT THE GROUND READER CANNOT ANSWER FOR: skip it, or give up? A truck gives up -- half a
	-- measurement is how a truck ends up tilted onto a wheel whose ground nobody knows. A tree keeps
	-- going, because its footprint is sampled on a GRID and a grid near the edge of the terrain has
	-- holes in it: measured, this was ten of thirty-eight trees left exactly where the arithmetic
	-- put them because one of twenty-five samples came back nil.
	skipMissing: boolean?,
}

local function settleOnGround(
	root: Instance,
	cfg,
	groundAt: ((number, number) -> number?)?,
	floorY: number,
	plan: SettlePlan?
): (boolean, number, number)
	if groundAt == nil then
		return false, 0, 0
	end
	local spec = cfg.TRUCK.SETTLE
	local wants = plan or ({} :: SettlePlan)
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
				if wants.skipMissing then
					continue
				end
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

	local first = sample(wants.contacts or contactsOf(parts))
	if first == nil or #first == 0 then
		return false, 0, 0
	end
	local slopeX, slopeZ = Build.groundFit(first :: any)
	local tilt = if wants.tilt == false
		then CFrame.identity
		else Build.tiltFrom(slopeX, slopeZ, math.rad(spec.MIN_TILT_DEGREES), math.rad(spec.MAX_TILT_DEGREES))
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

	-- THE CONTACTS ARE RE-READ ONLY IF THE TILT MOVED THEM. A plan that gave its own contacts and
	-- asked for no tilt is measuring points that have not moved, and re-deriving them from `parts`
	-- would throw the plan away.
	local second = if tilt == CFrame.identity and wants.contacts ~= nil then first else sample(contactsOf(parts))
	if second == nil or #second == 0 then
		return false, 0, 0
	end
	-- THE PLANTING HALF OF THIS IS `TreeGround.liftTo` SINCE TASK 199, and the lifting half stays
	-- here: a tree drops until no contact is in the air (`min`, and the forest's tool wants exactly
	-- that line), a truck lifts until no wheel is buried (`max`, which nothing else needs).
	local lift
	if wants.toLowest then
		local contacts = {}
		for _, point in ipairs(second :: any) do
			table.insert(contacts, { ground = point.y, bottom = point.bottom })
		end
		lift = TreeGround.liftTo(contacts, wants.sink or 0) or 0
	else
		lift = -math.huge
		for _, point in ipairs(second :: any) do
			lift = math.max(lift, point.y - point.bottom)
		end
		lift -= wants.sink or 0
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
	-- **IT POINTS WEST (-x) SINCE TASK 243**, and it pointed SOUTH (-z) before that. The row turned
	-- ninety degrees (Karen: *"there has to be cars but looking at me"*), and this branch has to turn
	-- with it or the harness's own lobby parks a truck across four bays and off the gravel.
	--
	-- IT IS WRITTEN IN THE TRUCK'S OWN FRAME AND TURNED ONCE, which is how the numbers stay readable
	-- against task 177's table: `across` is the width, `up` is the height and `along` runs from the
	-- NOSE at -9.6 to the TAILGATE at +8.2. `spot` and `box` are the only two places the quarter turn
	-- is applied -- `along` becomes world x and `across` becomes world -z -- so nothing below mixes
	-- the two frames the way `onLid` once did in `ShopDisplay`.
	local function spot(across: number, up: number, along: number): CFrame
		return CFrame.new(at.X + along, at.Y + up, at.Z - across)
	end
	local function box(wide: number, high: number, long: number): Vector3
		return Vector3.new(long, high, wide)
	end
	local bedAlong = 4
	part("Bed", box(7, 3.4, 8), spot(0, 4.4, bedAlong), green, Enum.Material.Metal, true, folder)
	for index, across in ipairs({ -3.4, 3.4 }) do
		part(
			string.format("BedSide%d", index),
			box(0.4, 2.6, 8),
			spot(across, 7.3, bedAlong),
			green,
			Enum.Material.Metal,
			false,
			folder
		)
	end
	part("BedTail", box(7, 2.6, 0.4), spot(0, 7.3, bedAlong + 4), green, Enum.Material.Metal, false, folder)
	part("Cab", box(7, 6.5, 6), spot(0, 5.9, -2.4), green, Enum.Material.Metal, true, folder)
	part(
		"Windscreen",
		box(6.2, 3, 0.4),
		spot(0, 7.4, -5.3),
		Color3.fromRGB(42, 52, 56),
		Enum.Material.Glass,
		false,
		folder
	)
	part("Bonnet", box(7, 2.8, 4), spot(0, 4.4, -7.4), green, Enum.Material.Metal, true, folder)
	part("Bumper", box(7.4, 1.2, 0.8), spot(0, 2.9, -9.6), dark, Enum.Material.Metal, false, folder)
	for index = 1, cfg.TRUCK.WHEELS do
		local across = if index % 2 == 0 then 3.6 else -3.6
		local along = if index <= 2 then -6 else 4
		-- **A `Cylinder`'S AXIS IS ITS X AXIS**, so a wheel whose axle runs ACROSS the truck has to
		-- be turned with everything else: a quarter about y takes that axis to world z.
		local wheel = part(
			string.format("Wheel%d", index),
			Vector3.new(2.2, 5, 5),
			spot(across, 2.5, along) * CFrame.Angles(0, math.pi / 2, 0),
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

-- ---------------------------------------------------------------- the truck that starts (task 197)
--
-- KAREN, 2026-10-15 ~17:40: *"also could be car started sound light on something like that
-- indicating loading ect"*.
--
-- IS THIS PART ONE OF THE TRUCK'S LAMPS? PURE over the four facts a part carries, and exported
-- because it is the whole of why no truck's geometry had to be guessed at.
--
-- IT IS `Build.truckSkinOf`'S OWN "light" CLASS, PLUS A SIZE. That classifier calls anything `Neon`
-- or named "light" a light, which is exactly right for the paint rule it was written for -- and the
-- free model's CHASSIS is a `Neon` part named `Light`, 6.70 x 4.50 x 17.65 studs. A classifier that
-- stopped at the name would have hung a SpotLight inside the chassis of all four trucks. A lamp is
-- small; `ENGINE.LAMP_MAX_STUDS` is 2.5 and the biggest real lamp measures 1.35.
function Build.isTruckLamp(name: string, material: Enum.Material, size: Vector3, cfg): boolean
	if Build.truckSkinOf(name, material) ~= "light" then
		return false
	end
	local bound = cfg.TRUCK.ENGINE.LAMP_MAX_STUDS
	return size.X <= bound and size.Y <= bound and size.Z <= bound
end

-- IS THIS LAMP A HEADLIGHT? PURE, and it is a WHITE test and nothing else: the free model's
-- headlights ship at 248,248,248 and every other lamp on it is amber (213,115,61) or red (255,89,89
-- / 190,104,98), whose lowest channel is 61, 89 and 98 against a threshold of 0.75.
function Build.isHeadLamp(color: Color3, cfg): boolean
	local floor = cfg.TRUCK.ENGINE.HEAD_MIN_CHANNEL
	return color.R >= floor and color.G >= floor and color.B >= floor
end

-- EVERY LAMP OF ONE TRUCK, SPLIT INTO HEADS AND TAILS, and WHICH WAY THE TRUCK FACES.
--
-- THE WHITE PAIR *IS* THE FRONT, whichever end of the box it sits on, and that is the one thing in
-- this task that could not be taken from a comment. `CONFIG.TRUCK`'s own header SAID the free model
-- *"is delivered pointing along its own +X"* from task 180 until task 243, and was wrong: the lamps
-- measure the other way round, and task 243 measured them again on a built truck -- the headlights
-- are at the model's local **-X**, so at `YAW_RADIANS` 0 they look WEST, at the pads. (`Build.truck`'s
-- fallback is built nose-west too, and ITS branch asserts that heading rather than measuring it,
-- because this file builds that geometry itself twenty lines below.) So nothing here reads a config
-- heading at all: the direction is measured from the truck's own centre out through its own white
-- lamps, and both branches come out right by construction -- which is why the config row being wrong
-- for three tasks cost nothing but a comment.
--
-- A TAIL IS A LAMP ON THE FAR HALF FROM THE HEADS, which is a POSITION test and not a colour test.
-- The model's amber indicators are the same hue family as its tail lights and sit at the FRONT; a
-- red glow on a bonnet is the kind of thing that measures correct and looks wrong
-- (`docs/PROJECT_CONTEXT.md`).
local function lampsOf(model: Instance, cfg): ({ BasePart }, { BasePart }, Vector3?)
	local heads: { BasePart } = {}
	local lamps: { BasePart } = {}
	for _, piece in ipairs(partsOf(model)) do
		if Build.isTruckLamp(piece.Name, piece.Material, piece.Size, cfg) then
			table.insert(lamps, piece)
			if Build.isHeadLamp(piece.Color, cfg) then
				table.insert(heads, piece)
			end
		end
	end
	if #heads == 0 then
		return {}, {}, nil
	end
	local centre = Build.worldBoxOf(model)
	local sum = Vector3.zero
	for _, head in ipairs(heads) do
		sum += head.Position
	end
	local flat = (sum / #heads - centre) * Vector3.new(1, 0, 1)
	-- A TRUCK WHOSE HEADLIGHTS ARE AT ITS OWN CENTRE HAS NO FRONT. It cannot happen on either branch
	-- and it is not an error: no facing, no beam, and the caller falls back to building its own.
	if flat.Magnitude < 0.5 then
		return {}, {}, nil
	end
	local facing = flat.Unit
	-- HOW LONG THE TRUCK IS ALONG THE WAY IT FACES, so "the far quarter" is a fraction of the truck
	-- and not a number of studs a different model would break.
	local _, half = Build.worldBoxOf(model)
	local lengthHalf = math.abs(facing.X) * half.X + math.abs(facing.Z) * half.Z
	local behind = -lengthHalf * cfg.TRUCK.ENGINE.TAIL_MIN_FRACTION
	local tails: { BasePart } = {}
	for _, lamp in ipairs(lamps) do
		-- **THE FAR QUARTER AND NOT THE FAR HALF**, and that is a measured correction (task 197 part
		-- 2). The free model's `B` lamp sits at local x +2.80 of a 9.2 half-length -- past the middle,
		-- so a far-HALF test called the HIGH CENTRE BRAKE LIGHT ON THE CAB ROOF a tail light and hung
		-- a red `PointLight` up there on every started truck. The like-for-like night pair showed what
		-- that did: the two NEIGHBOURING trucks, their wheels and the ground all washed salmon pink.
		if
			not Build.isHeadLamp(lamp.Color, cfg)
			and facing:Dot((lamp.Position - centre) * Vector3.new(1, 0, 1)) < behind
		then
			table.insert(tails, lamp)
		end
	end
	return heads, tails, facing
end

-- ONE TRUCK'S RIG, REMEMBERED, for `padParts`' stated reason: the owner's 10 Hz scan turns a truck on
-- and off without finding anything again, and a spec can ask for one without a `Workspace`. The
-- `off` / `on` colours are kept per lamp because the lamp is the MODEL'S OWN part and its shipped
-- colour is not ours to forget.
type TruckRig = {
	-- `was` IS THE LAMP'S SHIPPED MATERIAL. An unlit lamp is not emissive at all (task 197 part 2):
	-- at `Neon` with an "off" grey the headlamps still glowed white at night, so three dark trucks
	-- looked lit and the started one did not stand out. It is REMEMBERED rather than assumed --
	-- `Neon` is what this model ships and what the fallback lenses are built as, but neither is this
	-- file's to decide for the next model.
	lamps: { { piece: BasePart, on: Color3, off: Color3, was: Enum.Material } },
	lights: { Light },
	smoke: ParticleEmitter?,
	start: Sound?,
	idle: Sound?,
	running: boolean,
}

local truckRigs: { [number]: TruckRig } = {}
-- WHAT AN UNLIT LAMP IS MADE OF, remembered beside the rigs for one reason: `Build.setTruck` is
-- called by the owner's scan with an index and a boolean and is handed no config -- `Build.setPad`'s
-- signature exactly -- and one row read at build time is better than a config argument nobody else
-- in that function needs.
local offMaterial = Enum.Material.SmoothPlastic

-- A `Sound` CUT TO A MEASURED WINDOW. `PlaybackRegion` plus `LoopRegion`, which is the engine's own
-- way of playing part of an asset -- the alternative, `TimePosition` with a `Looped` sound, replays
-- from zero and so would re-start the engine on every pass:
--   https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion
--   https://create.roblox.com/docs/reference/engine/classes/Sound#LoopRegion
-- Both windows are measured off the asset's own `PlaybackLoudness` (`CONFIG.TRUCK.ENGINE`).
local function engineSound(
	name: string,
	id: string,
	from: number,
	to: number,
	volume: number,
	looped: boolean,
	cfg
): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(from, to)
	if looped then
		sound.LoopRegion = NumberRange.new(from, to)
	end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = cfg.TRUCK.ENGINE.ROLL_OFF_MIN_STUDS
	sound.RollOffMaxDistance = cfg.TRUCK.ENGINE.ROLL_OFF_MAX_STUDS
	return sound
end

-- THE RIG, BUILT ONCE WITH THE TRUCK AND BORN OFF. Every light `Enabled = false`, the emitter
-- `Enabled = false`, the lamps at their OFF colour and neither sound playing -- so a yard nobody is
-- standing in is four dark trucks, which is the state the game is in for all but a few seconds.
--
-- IT ADDS NO PART TO THE MODEL BRANCH. The lights hang inside the model's own lamps, and the
-- emitter and the two sounds hang off `Attachment`s -- which are not `BasePart`s, so the lobby's
-- 1500-part budget is untouched by three of the four pieces. Only a FALLBACK truck costs parts (four
-- lenses), because `Build.truck` builds no lamp at all.
local function truckRig(model: Instance, cfg): TruckRig
	local spec = cfg.TRUCK.ENGINE
	offMaterial = spec.OFF_MATERIAL
	local rig: TruckRig = { lamps = {}, lights = {}, smoke = nil, start = nil, idle = nil, running = false }
	local centre, half = Build.worldBoxOf(model)
	local heads, tails, facing = lampsOf(model, cfg)

	if facing == nil then
		-- NO LAMPS: build four. `Build.truck`'s fallback points its bonnet at `at.X - 7.4` **since
		-- task 243 turned the row west**, so this branch's front is `-X` -- the one place in this
		-- file a heading is asserted rather than measured, and it is asserted about geometry THIS
		-- FILE builds twenty lines up.
		--
		-- **IT WAS `(0, 0, -1)` UNTIL TASK 243 AND THAT WAS THE WHOLE OF ROUND 1's FINDING 1.** The
		-- fallback truck turned and its rig did not, which put its headlamps on its SOUTH FLANK,
		-- aimed its beams sideways across the bays and -- through `lengthHalf`, which reads
		-- `|look.X| * half.X + |look.Z| * half.Z` -- hung its exhaust and its engine off the wrong
		-- half of the box. So nothing below names an axis any more: the lenses are placed ALONG
		-- `facing` and ACROSS its perpendicular, out of the box's own extents on those two
		-- directions, and the next turn of the yard needs this constant changed and nothing else.
		facing = Vector3.new(-1, 0, 0)
		local look = facing :: Vector3
		local across = Vector3.new(-look.Z, 0, look.X)
		local lengthHalf = math.abs(look.X) * half.X + math.abs(look.Z) * half.Z
		local widthHalf = math.abs(across.X) * half.X + math.abs(across.Z) * half.Z
		local y = centre.Y - half.Y + 2 * half.Y * spec.LENS_HEIGHT_FRACTION
		for _, row in ipairs({
			{ name = "HeadLamp", sign = 1, colour = spec.HEAD_OFF_COLOR, head = true },
			{ name = "TailLamp", sign = -1, colour = spec.TAIL_OFF_COLOR, head = false },
		}) do
			for index, way in ipairs({ -1, 1 }) do
				local along = look * (row.sign * (lengthHalf + spec.LENS_STUDS.Z / 2))
				local side = across * (way * widthHalf * spec.LENS_SIDE_FRACTION)
				local at = Vector3.new(centre.X + along.X + side.X, y, centre.Z + along.Z + side.Z)
				-- **THE LENS IS TURNED WITH THE TRUCK TOO.** `LENS_STUDS` is written depth-last --
				-- its `Z` is the depth along the truck's length -- and a part built with a bare
				-- `CFrame.new` would lay that depth along WORLD z whichever way the truck points.
				-- `CFrame.lookAt` puts a part's own `-Z` face on the direction it is given, which
				-- is the one place in this file that mapping has to be written.
				local lens = part(
					string.format("%s%d", row.name, index),
					spec.LENS_STUDS,
					CFrame.lookAt(at, at + look),
					row.colour,
					Enum.Material.Neon,
					false,
					model
				)
				table.insert(if row.head then heads else tails, lens)
			end
		end
	end

	for _, head in ipairs(heads) do
		table.insert(rig.lamps, { piece = head, on = spec.HEAD_COLOR, off = spec.HEAD_OFF_COLOR, was = head.Material })
		head.Color = spec.HEAD_OFF_COLOR
		head.Material = spec.OFF_MATERIAL
		local beam = Instance.new("SpotLight")
		beam.Name = "Beam"
		beam.Brightness = spec.HEAD_BRIGHTNESS
		beam.Range = spec.HEAD_RANGE_STUDS
		beam.Angle = spec.HEAD_ANGLE_DEGREES
		beam.Color = spec.HEAD_COLOR
		beam.Shadows = true
		-- A `SpotLight` SHINES ALONG ITS PARENT'S `Face`, and the lamp part's own orientation is the
		-- model author's, not ours. So the beam is aimed with an `Attachment`, whose CFrame this file
		-- owns: the default `Face` of a `SpotLight` is `Front`, which is the attachment's own
		-- `LookVector`, and `CFrame.new(from, to)` is what points a LookVector at something.
		--
		-- **`WorldCFrame`, NOT `CFrame`.** `Attachment.CFrame` is in its PARENT PART'S space, and
		-- `facing` is a WORLD direction measured off the truck's box -- so writing it to `CFrame`
		-- would aim every beam by the lamp part's own rotation, which is the free model author's and
		-- is a quarter turn out on these trucks. This is the same class of mistake as a pivot read in
		-- the wrong frame, and it is invisible to a spec: a beam has no position to assert.
		local aim = Instance.new("Attachment")
		aim.Name = "Aim"
		aim.Parent = head
		aim.WorldCFrame = CFrame.new(head.Position, head.Position + (facing :: Vector3))
		beam.Parent = aim
		beam.Enabled = false
		table.insert(rig.lights, beam)
	end
	for _, tail in ipairs(tails) do
		table.insert(rig.lamps, { piece = tail, on = spec.TAIL_COLOR, off = spec.TAIL_OFF_COLOR, was = tail.Material })
		tail.Color = spec.TAIL_OFF_COLOR
		tail.Material = spec.OFF_MATERIAL
		-- A TAIL LAMP IS ITS OWN LENS, AND BY DEFAULT NOTHING ELSE (`TAIL_BRIGHTNESS` is 0). The
		-- rear-quarter night frame is why: the lit lens reads as a tail light on its own, and the
		-- `PointLight`s behind it turned twenty studs of ground, two neighbouring trucks and the
		-- lodge salmon pink. Above 0 the glow comes back, which is what makes it a dial.
		if spec.TAIL_BRIGHTNESS > 0 then
			local glow = Instance.new("PointLight")
			glow.Name = "Glow"
			glow.Brightness = spec.TAIL_BRIGHTNESS
			glow.Range = spec.TAIL_RANGE_STUDS
			glow.Color = spec.TAIL_COLOR
			glow.Shadows = false
			glow.Enabled = false
			glow.Parent = tail
			table.insert(rig.lights, glow)
		end
	end

	-- THE EXHAUST AND THE ENGINE, both on `Attachment`s of the truck's biggest part -- the only part
	-- of a free model this file can name without reading somebody else's naming scheme. A `Sound`
	-- under an `Attachment` is still a 3-D sound at that attachment's position, which is the whole
	-- reason for not simply hanging it on the model.
	local anchor: BasePart? = nil
	local biggest = -1
	for _, piece in ipairs(partsOf(model)) do
		local bulk = piece.Size.X * piece.Size.Y * piece.Size.Z
		if bulk > biggest then
			biggest, anchor = bulk, piece
		end
	end
	if anchor ~= nil then
		-- HOW LONG THE TRUCK IS ALONG THE DIRECTION IT FACES, and how wide across it. Measured from
		-- the box rather than assumed to be Z and X: `facing` is derived from the lamps and a truck
		-- parked across the yard would put its length on the other axis.
		local look = facing :: Vector3
		local across = Vector3.new(-look.Z, 0, look.X)
		local lengthHalf = math.abs(look.X) * half.X + math.abs(look.Z) * half.Z
		local widthHalf = math.abs(across.X) * half.X + math.abs(across.Z) * half.Z
		-- **PARENTED FIRST, THEN PLACED.** `Attachment.WorldCFrame` on an attachment with no parent
		-- part has no world to be in: it writes the LOCAL `CFrame` instead, and the moment the
		-- attachment is parented the engine multiplies that by the part's own CFrame. MEASURED in
		-- the live Forest Test on 2026-10-17, with the two lines the other way round: the exhaust
		-- came out at **(5783.8, 304.8, -5872.9)** against a lobby at (2893, 150, -2941) -- very
		-- nearly twice everything, which is exactly what `partCFrame * worldCFrame` looks like. The
		-- smoke was emitting three thousand studs away and the ENGINE SOUND, which is the whole of
		-- Karen's *"car started sound"*, was playing there with it. Invisible to every spec: an
		-- attachment has no spec-visible failure, only a position nobody looked at.
		local pipe = Instance.new("Attachment")
		pipe.Name = "Exhaust"
		pipe.Parent = anchor
		pipe.WorldCFrame = CFrame.new(
			centre
				- look * lengthHalf * 0.92
				+ across * widthHalf * spec.SMOKE_SIDE_FRACTION
				+ Vector3.new(0, -half.Y * (1 - 2 * spec.SMOKE_HEIGHT_FRACTION), 0)
		)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Smoke"
		smoke.Texture = spec.SMOKE_TEXTURE
		smoke.Rate = spec.SMOKE_RATE
		smoke.Lifetime = NumberRange.new(spec.SMOKE_LIFETIME_SECONDS * 0.7, spec.SMOKE_LIFETIME_SECONDS)
		smoke.Speed = NumberRange.new(spec.SMOKE_SPEED_STUDS * 0.6, spec.SMOKE_SPEED_STUDS)
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, spec.SMOKE_SIZE_STUDS * 0.3),
			NumberSequenceKeypoint.new(1, spec.SMOKE_SIZE_STUDS),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, spec.SMOKE_TRANSPARENCY),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Color = ColorSequence.new(spec.SMOKE_COLOR)
		smoke.LightEmission = 0
		smoke.Acceleration = Vector3.new(0, 2.5, 0)
		smoke.Enabled = false
		smoke.Parent = pipe
		rig.smoke = smoke

		local block = Instance.new("Attachment")
		block.Name = "Engine"
		block.Parent = anchor
		block.WorldCFrame = CFrame.new(centre + look * lengthHalf * 0.7 + Vector3.new(0, -half.Y * 0.4, 0))
		rig.start = engineSound(
			"EngineStart",
			spec.START_SOUND_ID,
			spec.START_FROM,
			spec.START_TO,
			spec.START_VOLUME,
			false,
			cfg
		);
		(rig.start :: Sound).Parent = block
		rig.idle =
			engineSound("EngineIdle", spec.IDLE_SOUND_ID, spec.IDLE_FROM, spec.IDLE_TO, spec.IDLE_VOLUME, true, cfg);
		(rig.idle :: Sound).Parent = block
	end
	return rig
end

-- IS TRUCK n RUNNING? nil for a truck that was never built -- `Build.padLabel`'s read seam, on the
-- truck's side, so a spec and a console probe read what was WRITTEN instead of guessing.
function Build.truckRunning(index: number): boolean?
	local rig = truckRigs[index]
	return if rig == nil then nil else rig.running
end

-- WHAT THE RIG IS MADE OF, as counts, for the same reason: *"the panel reads"* said about geometry.
function Build.truckRigCounts(index: number): (number, number, boolean)
	local rig = truckRigs[index]
	if rig == nil then
		return 0, 0, false
	end
	return #rig.lamps, #rig.lights, rig.smoke ~= nil and rig.start ~= nil and rig.idle ~= nil
end

-- TRUCK n, RUNNING OR DARK. **THE ONE WRITER** of every lamp colour, every light's `Enabled`, the
-- emitter's `Enabled` and the two sounds -- and WHETHER it is running is `Lobby.step`'s to decide,
-- which is `Build.setPad`'s and `Build.faceKeeper`'s arrangement exactly.
--
-- IT IS A RECONCILE AND NOT AN EVENT, and that is deliberate (the Learning Agent's L-029): the owner
-- asks this every scan with the answer `Lobby.padLoading` gives for that pad, so a party that
-- cancels, resets, departs or is interrupted leaves no truck idling with nobody in it. It returns
-- whether it WROTE anything, so `stats.truckWrites` counts EDGES and a counter that climbs with
-- `stats.scans` is a bug the spec catches (`padWrites`' own rule).
function Build.setTruck(index: number, on: boolean): boolean
	local rig = truckRigs[index]
	if rig == nil or rig.running == on then
		return false
	end
	rig.running = on
	for _, lamp in ipairs(rig.lamps) do
		if lamp.piece:IsDescendantOf(game) then
			lamp.piece.Color = if on then lamp.on else lamp.off
			-- THE MATERIAL GOES WITH THE COLOUR: emissive while it is lit, and not emissive at all
			-- when it is not. A dark `Neon` lamp still glows at night, which is how three unlit
			-- trucks came to look lit in the first night frames.
			lamp.piece.Material = if on then lamp.was else offMaterial
		end
	end
	for _, light in ipairs(rig.lights) do
		if light:IsDescendantOf(game) then
			light.Enabled = on
		end
	end
	if rig.smoke ~= nil and (rig.smoke :: ParticleEmitter):IsDescendantOf(game) then
		(rig.smoke :: ParticleEmitter).Enabled = on
	end
	-- THE START IS A ONE-SHOT AND THE IDLE IS THE LOOP UNDER IT, so turning a truck on sounds like a
	-- truck starting and turning it off is silence rather than a second start.
	if rig.start ~= nil and (rig.start :: Sound):IsDescendantOf(game) then
		if on then
			(rig.start :: Sound):Play()
		else
			(rig.start :: Sound):Stop()
		end
	end
	if rig.idle ~= nil and (rig.idle :: Sound):IsDescendantOf(game) then
		if on then
			(rig.idle :: Sound):Play()
		else
			(rig.idle :: Sound):Stop()
		end
	end
	stats.truckWrites += 1
	return true
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
	-- THE NAME IS DATA SINCE TASK 197, because the CLIENT finds this folder too (`Lobby.truckPosition`,
	-- which the Hud asks so the camera can turn toward the right truck). One spelling of "Trucks".
	folder.Name = Data.TRUCKS_NAME
	local model = cfg.TRUCK.MODEL
	-- THE TOP OF THE YARD SLAB, which is the surface a truck in a parked bay stands on when the
	-- terrain under it is lower. `road` lays `Yard` across all four bays at `anchor.Y + THICK / 2`,
	-- so its top is `anchor.Y + THICK` -- the same bound `pad` holds its deck above, for the same
	-- reason and out of the same row.
	local floorY = anchor.Y + cfg.ROAD.THICK_STUDS
	for index = 1, cfg.TRUCK.COUNT do
		-- **THE BAY STEPS SOUTH AND THE TRUCK STANDS `BACK_STUDS` EAST OF IT** (task 243; it stepped
		-- east with the truck `BACK_STUDS` south until this task). Karen, 2026-10-22: *"there has to
		-- be cars but looking at me ... but not close to house there has to be distance"*. The bay
		-- centre itself is still the one anchor everything else is derived from -- the pad
		-- (`Pads.centreFor`), the yard and the billboards -- and nothing but the parked body is
		-- shifted by `BACK_STUDS`; `+x` is away from the pad, which is west of it. This is the ONE
		-- reader of `BACK_STUDS`, and task 209's eight studs are untouched: only the axis turned.
		local at = anchor
			+ cfg.TRUCK.OFFSET
			+ Vector3.new(cfg.TRUCK.BACK_STUDS, 0, -(index - 1) * cfg.TRUCK.BAY_GAP_STUDS)
		local name = string.format(Data.TRUCK_NAME, index)
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
		-- RIGGED LAST, AFTER THE SETTLE (task 197), and the order is load-bearing rather than
		-- readability: `truckRig` measures the truck's own box to aim a beam and place an exhaust, and
		-- `settleOnGround` MOVES and TILTS the whole model. Rigged first, every attachment would be
		-- placed against a box that no longer exists -- up to 2.0 studs out at the east bay by task
		-- 186's own measurement. The lights hang inside the model's parts and the attachments are
		-- `WorldCFrame`'d once, so nothing after this moves them.
		truckRigs[index] = truckRig(made :: Instance, cfg)
		stats.truckRigs += 1
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
	-- ...AND IT IS ASKED IN NINE PLACES AND NOT ONE (task 213), WHICH IS TASK 196'S FINDING ON A
	-- THIRD SURFACE: *"WHY ONE SAMPLE IS NOT ENOUGH, which is the whole bug: `plantY` asked for the
	-- ground at the PLANTING POINT"* -- a birch stood on its high root with daylight under the rest.
	-- A pad is nine studs across, and one ray at its centre says nothing about its corners.
	--
	-- MEASURED, 2026-10-19, in the live Forest Test, when `PAD_BEHIND_STUDS` brought the pads south
	-- to Karen's gap: the yard is dead flat under pads 1, 2 and 3 (81 rays each, spread 0.000), and
	-- under pad 4 the old east hill -- the same 1.27 studs of it that `TRUCK.SETTLE` was written for
	-- -- rises 0.936 studs across the rectangle's south-east corner. With the centre ray alone, 8 of
	-- pad 4's 81 samples came out ABOVE the deck's top: its corner and part of its east rim were
	-- underground, which is task 182's own defect (*"laid on the ground that is MEASURED"*) in the
	-- one place the ground is not level. Both frames are in the task-213 review request.
	--
	-- THE HIGHEST SAMPLE WINS, because the thing being prevented is a BURIED deck. A flat slab on
	-- sloping ground cannot be flush at both ends, and of the two ways to be wrong -- a corner you
	-- cannot see, or an edge standing a third of a stud proud -- only one of them hides the
	-- rectangle Karen is told to stand on. The truck beside it answers the same ground by TILTING
	-- (`settleOnGround`); a pad is one part plus its rim and its board, and tilting those is a
	-- rotation this system has no other reason to own, so it takes the lift and states the cost.
	if groundAt ~= nil then
		local highest: number? = nil
		for _, dx in ipairs({ -1, 0, 1 }) do
			for _, dz in ipairs({ -1, 0, 1 }) do
				local ok, measured = pcall(groundAt, centre.X + dx * size.X / 2, centre.Z + dz * size.Z / 2)
				if ok and type(measured) == "number" then
					local here = measured :: number
					highest = if highest == nil then here else math.max(highest :: number, here)
				end
			end
		end
		if highest ~= nil then
			local surface = math.max(highest :: number, anchor.Y + cfg.ROAD.THICK_STUDS)
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

	-- **THE BAY'S NUMBER, PAINTED ON THE DECK** (task 243, the Designer's `lobby-yard-spec.md`
	-- section 3b). TWO INDEPENDENT MARKS, ON PURPOSE: the board above carries the LIVE COUNT, which
	-- has to float; this carries the IDENTITY, which does not. A numeral lying on the ground cannot
	-- be occluded by another pad's board, it is readable from directly above while you are standing
	-- on it, and it is one instance per pad. If the two ever disagree the DECK is right -- it is
	-- painted from `index` here and nothing writes to it afterwards, while `Build.setPad` rewrites
	-- the board ten times a second.
	--
	-- A `SurfaceGui` ON THE `Top` FACE, which is the one face of a deck a man walking the yard can
	-- see. `PixelsPerStud` is what makes the numeral a SIZE IN STUDS rather than a size in pixels:
	-- unlike the billboard above it, this mark DOES shrink with distance, because it is painted on
	-- the ground rather than hung over it.
	--
	-- THE FACE IS OSWALD SEMIBOLD, WRITTEN OUT RATHER THAN REQUIRED. `Hud.Style.FONT.OSWALD_SB` is
	-- the one this mirrors and the house face for every NUMBER in this game (`Style.faceFor`), but
	-- `Style` is a CLIENT module and this is the server's builder -- so the two cannot share a
	-- value without this file reaching across that boundary for a font.
	local deckBoard = Instance.new("SurfaceGui")
	deckBoard.Name = "Deck"
	deckBoard.Face = Enum.NormalId.Top
	deckBoard.Adornee = deck
	deckBoard.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	deckBoard.PixelsPerStud = config.DECK.PIXELS_PER_STUD
	deckBoard.AlwaysOnTop = false
	deckBoard.LightInfluence = 0
	deckBoard.Parent = deck

	local numeral = Instance.new("TextLabel")
	numeral.Name = "Numeral"
	numeral.BackgroundTransparency = 1
	numeral.Size = UDim2.fromScale(1, 1)
	numeral.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold)
	numeral.TextSize = config.DECK.NUMERAL_STUDS * config.DECK.PIXELS_PER_STUD / config.DECK.CAP_FRACTION
	numeral.TextColor3 = colour
	numeral.TextTransparency = config.DECK.TRANSPARENCY
	-- **THE GLYPH'S TOP POINTS AWAY FROM THE MAN WALKING UP TO IT.** A `SurfaceGui` on a `Top` face
	-- draws with its own up pointing WEST -- toward the man walking out of the lodge, which draws
	-- the numeral upside down to him -- so it is turned a HALF (`DECK.ROTATION_DEGREES`, which
	-- carries the measurement). Looked at at 0, 90 and 180 in the live place before it was written.
	numeral.Rotation = config.DECK.ROTATION_DEGREES
	numeral.Text = tostring(index)
	-- THE SAME BLACK OUTLINE EVERY LABEL IN THIS GAME WEARS (`ShopPanel.label`, `boardLabel` below),
	-- and here it is load-bearing rather than house style: the numeral is the PAD'S OWN COLOUR on
	-- the pad's own coloured deck, which is a green glyph on a green rectangle. MEASURED, 2026-10-22
	-- in the live Forest Test: without the stroke the numeral came out as a pale smudge from the
	-- porch, 47 studs away. A document that cannot be read is worse than no document
	-- (`ShopDisplay.LICENCE.MIN_WIDTH_PX`'s own rule, on a different surface).
	local edge = Instance.new("UIStroke")
	edge.Thickness = config.DECK.STROKE_PX
	edge.Color = Color3.new(0, 0, 0)
	edge.Parent = numeral
	numeral.Parent = deckBoard

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

-- WHERE THE YARD IS, AS ONE RECTANGLE, SAID ONCE (task 209). Returns its centre and its half-spans
-- in x and z, in WORLD studs.
--
-- IT EXISTS BECAUSE THERE WERE TWO ANSWERS. The slab in `road` and the tree exclusion in `trees`
-- each built the same rectangle out of the same four config rows, and each carried its own copy of
-- the literals (`+ 34` and `44` in one, `+ 34` and `26` in the other). Task 209 moves the trucks and
-- the pads apart, which changes the rectangle -- and two answers to "where is the yard" is how a
-- spruce ends up standing on a queue pad, which is this repository's named failure mode
-- (`docs/PROJECT_CONTEXT.md`). One function, two callers.
--
-- **THE TWO MARGINS KEEP THEIR VALUES AND SWAP AXES IN TASK 243** (the Designer's
-- `lobby-yard-spec.md` section 2d), because the row turned: `YARD_END_STUDS` is now the gravel past
-- the two ends of the row in **z**, and `YARD_LIP_STUDS` the gravel past the trucks' east end and
-- past the pads' west edge in **x**.
--
-- **THE WEST EDGE IS THE ROAD'S EAST VERGE AND NOT ITS CENTRE LINE**, and that is a correction this
-- task had to make rather than a translation: written to `ROAD.CENTRE_X`, the old rectangle put half
-- the lane inside the yard. At the verge the two surfaces abut and the lane stays a lane. `road()`
-- draws Lane, then Verges, then Yard -- **do not reorder those three**, or the verge paints over the
-- gravel at the seam.
--
-- **THE EAST EDGE IS BOUNDED, NOT CHOSEN** (section 2e). `treeLine` SKIPS any tree that lands inside
-- this rectangle, so pushing the yard further out at "the trees" punches a hole in the tree line
-- directly behind the trucks: at bay x 70 the gravel reaches 91.2 and the arc's own x over the
-- yard's z band runs 80.8 .. 89.1 -- ALL of it inside, a hundred studs of missing wood. At bay 58
-- the east edge is 79.23, the ceiling is 80.8, and not one tree is lost. The rule, for whoever
-- retunes this next: `OFFSET.X + BACK_STUDS + LENGTH/2 + YARD_LIP` must stay BELOW
-- `TREELINE.RADIUS_STUDS * sin(a)` for every bearing `a` whose `RADIUS * cos(a)` falls in the band
-- -- and `lobby.spec` asserts it rather than leaving it in this paragraph.
function Build.yardRect(anchor: Vector3, cfg): (number, number, number, number)
	local bays = (cfg.TRUCK.COUNT - 1) * cfg.TRUCK.BAY_GAP_STUDS
	local lip = cfg.ROAD.YARD_LIP_STUDS
	local west = cfg.ROAD.CENTRE_X + cfg.ROAD.WIDTH_STUDS / 2 + cfg.ROAD.VERGE_STUDS
	local east = cfg.TRUCK.OFFSET.X + cfg.TRUCK.BACK_STUDS + cfg.TRUCK.MODEL.LENGTH_STUDS / 2 + lip
	local north = cfg.TRUCK.OFFSET.Z + cfg.ROAD.YARD_END_STUDS / 2
	local south = cfg.TRUCK.OFFSET.Z - bays - cfg.ROAD.YARD_END_STUDS / 2
	return anchor.X + (west + east) / 2, (east - west) / 2, anchor.Z + (north + south) / 2, (north - south) / 2
end

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
	-- standing in a meadow. ONE rectangle, from `yardRect`, which `trees` asks for too.
	local yardMidX, yardHalfX, yardMidZ, yardHalfZ = Build.yardRect(anchor, cfg)
	part(
		"Yard",
		Vector3.new(yardHalfX * 2, spec.THICK_STUDS, yardHalfZ * 2),
		CFrame.new(yardMidX, top, yardMidZ),
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
-- WHICH MODEL A SPECIES WANTS, and what to paint it. PURE and exported, so the allow-list is a
-- spec rather than a belief about a folder nobody can read in a diff (spec 16b).
--
-- A WEIGHTED PICK over `TREELINE.SPECIES`: the birch is 3 and the alder 2, so a ring of thirty comes
-- out roughly 18 birch to 12 alder, which is what a damp Lithuanian field edge looks like.
function Build.speciesAt(roll: number, cfg): any
	local list = cfg.TREELINE.SPECIES
	local total = 0
	for _, row in ipairs(list) do
		total += row.WEIGHT
	end
	local pick = (roll % 1) * total
	local seen = 0
	for _, row in ipairs(list) do
		seen += row.WEIGHT
		if pick < seen then
			return row
		end
	end
	return list[#list]
end

-- WHAT ONE PART OF A TREE IS, FOR THE ALDER'S REPAINT. PURE and exported -- `Build.truckSkinOf`'s
-- own shape, and for its stated reason: a rule about somebody else's model has to be readable in a
-- diff. `"trunk"`, `"leaf"` or `"none"`, decided from the NAME and the MATERIAL and nothing else.
function Build.treeSkinOf(name: string, material: Enum.Material): string
	local lower = string.lower(name)
	for _, word in ipairs({ "bark", "trunk", "stem", "branch", "wood" }) do
		if string.find(lower, word, 1, true) then
			return "trunk"
		end
	end
	for _, word in ipairs({ "leaf", "leaves", "canopy", "foliage", "card" }) do
		if string.find(lower, word, 1, true) then
			return "leaf"
		end
	end
	if material == Enum.Material.LeafyGrass or material == Enum.Material.Grass then
		return "leaf"
	end
	if material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		return "trunk"
	end
	return "none"
end

-- THE ALDER, PAINTED ONTO A FOREST OAK (spec 16b(3)). There is no alder model in this place -- that
-- is measured, not assumed -- so the nearest shape in the library is re-tinted and held small.
-- Counted, like every other repaint in this file, so "how many trees were tinted" is a number and
-- not a belief.
local function tintAlder(tree: Instance, cfg): number
	local painted = 0
	for _, descendant in ipairs(tree:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local piece = descendant :: BasePart
			local skin = Build.treeSkinOf(piece.Name, piece.Material)
			if skin == "trunk" then
				piece.Color = cfg.ALDER.TRUNK_COLOR
				painted += 1
			elseif skin == "leaf" then
				piece.Color = cfg.ALDER.LEAF_COLOR
				painted += 1
			end
		end
	end
	stats.treesTinted += painted
	return painted
end

-- THE BOX NO TREE MAY STAND IN: the house, its eaves, its gables, its porch and its chimney, in the
-- FIELD'S frame and offset from the anchor. PURE, so `lobby.spec` can assert it without building a
-- lodge, and computed from the same `CONFIG` numbers the roof is built from rather than from a
-- hand-copied rectangle.
--
-- WHY A BOX AND NOT A RADIUS ROUND THE PIVOT (part 3c): a tree's pivot can stand twenty studs clear
-- of the house while its TRUNK leans through the roof, because these models lean and their crowns
-- are wider than they are tall. The Director photographed exactly that. The test below is run
-- against the planted model's real world bounding box -- every BasePart of it -- and not against the
-- point it was planted on.
function Build.lodgeKeepOut(cfg): (Vector3, Vector3)
	local size = cfg.LODGE.SIZE
	local eaves = cfg.LODGE.ROOF
	local deck = cfg.LODGE.PORCH
	-- THE CHIMNEY IS WIDER THAN THE GABLE OVERHANG and stands on the west end, so the box is
	-- MEASURED against both: 18 + 2.2 is 20.2, and the lodge's real west face was measured at 21.6.
	local halfX = math.max(size.X / 2 + eaves.GABLE_STUDS, size.X / 2 + cfg.LODGE.CHIMNEY.BASE_DEPTH / 2)
	-- THE LODGE FACES SOUTH, so the porch and its steps hang off -Z and the box is not symmetric.
	local north = size.Z / 2 + eaves.EAVE_STUDS
	local south = size.Z / 2 + eaves.EAVE_STUDS + deck.DEPTH + deck.STEP_DEPTH
	-- UP TO THE CHIMNEY CAP AND A LITTLE BELOW THE SHELF, because `groundAt` is not `anchor.Y`.
	local top = cfg.LODGE.RIDGE_STUDS + 6
	local bottom = -4
	return cfg.LODGE.OFFSET + Vector3.new(0, (top + bottom) / 2, (north - south) / 2),
		Vector3.new(halfX, (top - bottom) / 2, (north + south) / 2)
end

-- WHERE TO ASK "HOW LOW IS THE GROUND HERE" UNDER ONE TREE (task 196 part 3d). Karen, 2026-10-16:
-- *"look at the trees wtf"* -- birches standing on their splayed roots with daylight under them.
--
-- WHY ONE SAMPLE IS NOT ENOUGH, which is the whole bug: `plantY` asked for the ground at the
-- PLANTING POINT and `sitOnShelf` then put the model's lowest point there. A birch's root flare is
-- eight or nine studs across, so beside a road cut or on a bank the ground under the OUTER root tips
-- is one to three studs lower than the ground under the trunk -- and the tree stands on the high
-- side with its other roots in the air. The part-3c check made the identical mistake in the
-- identical place, which is why it reported zero: it rayed at the bounding box's centre.
--
-- A GRID PLUS THE CORNERS, in the model's own footprint, and the corners matter most because that
-- is where the root tips are. Pure, so `lobby.spec` can assert the pattern without a world.
--
-- THE GRID ITSELF IS `TreeGround.samples` SINCE TASK 199, and this is the Vector2 face of it: the
-- forest's re-seating tool needs the identical pattern in a place Rojo does not serve, so the
-- arithmetic moved to the shared module and nothing here restates it.
function Build.footprintSamples(min: Vector3, max: Vector3, steps: number): { Vector2 }
	local out = {}
	for _, point in ipairs(TreeGround.samples(min.X, min.Z, max.X, max.Z, steps)) do
		table.insert(out, Vector2.new(point.x, point.z))
	end
	return out
end

-- A MODEL'S REAL WORLD BOX, AXIS-ALIGNED. `Model:GetBoundingBox()` returns an ORIENTED box -- its
-- CFrame carries the model's own rotation -- so treating its position and size as an axis-aligned
-- box is wrong for anything that has been turned, and every tree here is turned by a random yaw.
-- That is why the first version of this check still let seven tree parts stand in the house.
--
-- EVERY PART, PROJECTED: half the part's size dotted through the absolute value of its rotation is
-- the part's own axis-aligned reach, which is the same projection `lobby.spec` clamps trophies with.
function Build.worldBoxOf(model: Instance): (Vector3, Vector3)
	local min, max
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local piece = descendant :: BasePart
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = piece.CFrame:GetComponents()
			local size = piece.Size
			local reach = Vector3.new(
				0.5 * (math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z),
				0.5 * (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z),
				0.5 * (math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z)
			)
			local low, high = piece.Position - reach, piece.Position + reach
			if min == nil then
				min, max = low, high
			else
				min = Vector3.new(math.min(min.X, low.X), math.min(min.Y, low.Y), math.min(min.Z, low.Z))
				max = Vector3.new(math.max(max.X, high.X), math.max(max.Y, high.Y), math.max(max.Z, high.Z))
			end
		end
	end
	if min == nil then
		return Vector3.zero, Vector3.zero
	end
	return (min + max) / 2, (max - min) / 2
end

-- TWO AXIS-ALIGNED BOXES, OR NOT. Pure, and the one place the margin is applied.
function Build.boxesOverlap(aAt: Vector3, aHalf: Vector3, bAt: Vector3, bHalf: Vector3, margin: number): boolean
	local m = Vector3.new(margin, margin, margin)
	local gap = aAt - bAt
	local reach = aHalf + bHalf + m
	return math.abs(gap.X) < reach.X and math.abs(gap.Y) < reach.Y and math.abs(gap.Z) < reach.Z
end

-- THE SURFACE A PLAYER ACTUALLY WALKS ON AT A POINT, which is not always the terrain (task 196
-- part 3f). This lobby lays its road, its verges and its yard as PARTS on top of the terrain shelf,
-- half a stud proud of it -- `road` says so in its own header, and it is why the first build of the
-- road came back as "a field and NO ROAD". A tree seated by `terrainYAt` alone would therefore be
-- planted to the terrain UNDER the slab and come up through it.
--
-- NO TREE DOES THAT TODAY -- measured, 0 of 38, because `treeLine` already keeps off the road
-- corridor, the yard and the gathering pad, and the grove's rows are placed clear. This is the same
-- kind of guard as the gathering-yard exclusion beside it: it removes nothing now, and what it is
-- for is the next edit -- a wider yard, a shorter radius, one more hand-placed grove row.
--
-- PURE, AND OVER THE PARTS THAT ARE ALREADY BUILT: `road` runs before `treeLine` in `Build.build`,
-- so the slabs exist to be asked.
function Build.surfaceOver(slabs: { BasePart }, x: number, z: number): number?
	local best = nil
	for _, piece in ipairs(slabs) do
		local half = piece.Size / 2
		if math.abs(x - piece.Position.X) <= half.X and math.abs(z - piece.Position.Z) <= half.Z then
			local top = piece.Position.Y + half.Y
			if best == nil or top > best then
				best = top
			end
		end
	end
	return best
end

-- THE GROUND READER A TREE IS PLANTED WITH: the terrain, or the walkable slab over it, whichever is
-- HIGHER. nil where neither answers, which `treePlan`'s `skipMissing` already tolerates.
local function walkableReader(
	slabs: { BasePart },
	terrainAt: ((number, number) -> number?)?
): ((number, number) -> number?)?
	if terrainAt == nil then
		return nil
	end
	return function(x: number, z: number): number?
		local ground = terrainAt(x, z)
		local slab = Build.surfaceOver(slabs, x, z)
		if ground == nil then
			return slab
		end
		if slab == nil then
			return ground
		end
		return math.max(ground, slab)
	end
end

-- HOW CLEAR A TREE HAS TO STAND OF THE HOUSE. The Designer's lodge spec, 2026-10-16, section 16c:
-- *"nothing through the roof, every crown >= 3.0 studs clear"*.
local TREE_MARGIN_STUDS = 3.0

-- WHERE A TREE'S FOOT GOES: on the ground the engine really produced, sunk by `SINK_STUDS`.
--
-- THE SINKING BUG (spec 16a, measured 2026-10-16): 18 of the 27 ring trees stood more than 2 studs
-- clear of the ground, worst 5.55, because `treeLine` planted every clone at the NOMINAL shelf
-- (`anchor.Y`) and `Build.build` never handed it `seams.groundAt` at all. Roblox terrain is
-- voxelised and the real surface is not the nominal one. This is the identical defect task 186
-- fixed for the truck wheels and task 182 for the pads, with the identical fix: ask the world.
local function plantY(at: Vector3, anchor: Vector3, cfg, groundAt: ((number, number) -> number?)?): number
	local ground = if groundAt ~= nil then groundAt(at.X, at.Z) else nil
	return (ground or anchor.Y) - cfg.TREELINE.SINK_STUDS
end

-- MOVE IT OUT OR DROP IT, and say which. The tree is planted first and MEASURED second, because
-- the only honest test of a leaning model is where its parts actually ended up. If it fouls the
-- house it is walked straight out along the line from the house to its foot, 7 studs at a time,
-- re-seated on the ground at each step; if six steps will not clear it, it is destroyed rather than
-- left standing in the roof.
local function clearOfLodge(
	planted: Instance,
	foot: Vector3,
	anchor: Vector3,
	cfg,
	groundAt: ((number, number) -> number?)?
): boolean
	if not planted:IsA("Model") then
		return true
	end
	local model = planted :: Model
	local keepAt, keepHalf = Build.lodgeKeepOut(cfg)
	keepAt += anchor
	local away = Vector3.new(foot.X - keepAt.X, 0, foot.Z - keepAt.Z)
	if away.Magnitude < 0.01 then
		away = Vector3.new(1, 0, 0)
	end
	away = away.Unit
	local at = foot
	for _ = 0, 6 do
		local boxAt, boxHalf = Build.worldBoxOf(model)
		if not Build.boxesOverlap(boxAt, boxHalf, keepAt, keepHalf, TREE_MARGIN_STUDS) then
			return true
		end
		at += away * 7
		-- MOVED BY THE DELTA OF ITS OWN BOUNDING BOX, never by setting the pivot to a point: a free
		-- model's pivot is its box centre only while nobody has set a `PrimaryPart`, and `cloneInstance`
		-- makes the same correction for the same reason.
		boxAt, boxHalf = Build.worldBoxOf(model)
		local wantBottom = plantY(at, anchor, cfg, groundAt)
		model:PivotTo(
			model:GetPivot() + Vector3.new(at.X - boxAt.X, wantBottom - (boxAt.Y - boxHalf.Y), at.Z - boxAt.Z)
		)
		stats.treesMoved += 1
	end
	stats.treesDropped += 1
	planted:Destroy()
	return false
end

-- WHERE A TREE TOUCHES THE GROUND, AND IT IS NOT THE BOTTOM OF THE MODEL (task 196 part 3e).
--
-- KAREN PHOTOGRAPHED THIS TWICE. Part 3d sank each tree until its LOWEST point reached the lowest
-- ground, which is exactly right for a truck and exactly wrong for a birch: `SilverBirch_Var11`'s
-- root flare is a set of ARCHED CLAWS, so putting the claw TIPS on the ground leaves daylight under
-- every arch -- and to the eye that is a floating tree. The Director, on part 3d's own
-- `trees-2-grove-by-the-lodge.png`: *"the birch's root flare arches like claws with daylight under
-- it"*, and *"the tips are in the ground, the arch is the model's shape" is not acceptable*.
--
-- THE CONTACT IS THE TRUNK/FLARE JUNCTION -- the height at which the base stops being claws and
-- becomes trunk -- and the claws go UNDER the ground. That height is a property of the MESH, so it
-- is measured once per model and stored as data, `TREELINE.SPECIES[n].CLAW_FRACTION`, as a fraction
-- of the model's height so it survives the per-tree random scale. How it was measured is written
-- out beside the numbers.
--
-- IT RUNS AFTER THE CLONE IS PLACED, because the footprint it samples is the footprint the model
-- actually ended up with: these models lean, and their scale is a per-tree random.
local function treePlan(model: Model, cfg, clawFraction: number): any
	local at, half = Build.worldBoxOf(model)
	local min, max = at - half, at + half
	-- THE JUNCTION, IN THE WORLD. Every contact shares it, so `toLowest` settles the junction onto
	-- the lowest ground anywhere under the tree and the claws bury themselves on the high side.
	-- `TreeGround.junctionY` SINCE TASK 199: the same line, in the module the forest's tool also
	-- carries, so "where the claws stop" is defined once for the whole game.
	local junction = TreeGround.junctionY(min.Y, max.Y, clawFraction)
	-- THE **BASE'S** FOOTPRINT AND NOT THE CROWN'S, which is a correction measured on the first
	-- build of this: a birch's crown is twenty-five studs across and its root flare is eight, so a
	-- grid over the whole bounding box reads the ground under the CANOPY -- twelve studs from the
	-- trunk, down a bank or off the edge of the terrain -- and settles the tree to that. The
	-- contacts are the parts that are actually near the ground.
	local low, high = nil, nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant :: BasePart).Transparency < 0.95 then
			local piece = descendant :: BasePart
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = piece.CFrame:GetComponents()
			local size = piece.Size
			local ry = 0.5 * (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z)
			if piece.Position.Y - ry <= junction + (max.Y - min.Y) * clawFraction then
				local rx = 0.5 * (math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z)
				local rz = 0.5 * (math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z)
				local a = Vector3.new(piece.Position.X - rx, 0, piece.Position.Z - rz)
				local b = Vector3.new(piece.Position.X + rx, 0, piece.Position.Z + rz)
				if low == nil then
					low, high = a, b
				else
					low = Vector3.new(math.min(low.X, a.X), 0, math.min(low.Z, a.Z))
					high = Vector3.new(math.max(high.X, b.X), 0, math.max(high.Z, b.Z))
				end
			end
		end
	end
	local baseMin = if low ~= nil then Vector3.new(low.X, min.Y, low.Z) else min
	local baseMax = if high ~= nil then Vector3.new(high.X, max.Y, high.Z) else max
	-- THE FOREST'S FLARE CLAMP (`TreeGround.flareFootprint`, task 199) IS DELIBERATELY NOT APPLIED
	-- HERE, and that is a measurement rather than a preference. I added it, claimed it was inert
	-- for these two templates, and `lobby.spec`'s own "buries each tree's root claws" case failed:
	-- on its test slope the clamp narrows the sampled strip, the lowest reading comes up, and every
	-- tree sinks LESS than the 0.6 `SINK_STUDS` the case holds them to.
	--
	-- WHY THE FOREST NEEDS IT AND THIS DOES NOT. The footprint above is already the union of the
	-- parts that REACH THE GROUND, and these two templates' trunk parts are 3.7 and 2.0 studs
	-- across -- the near-ground parts ARE the flare. `Workspace.OurForest`'s are not: a
	-- `LarchTree_Var02`'s single "Trunk" mesh is 15.6 studs across and carries the whole lower
	-- tree, so the clamp is the only thing between its corners and the ground seven studs away,
	-- down a bank. One function, and the caller that does not need the guard does not pay for it.
	local contacts = {}
	for _, point in ipairs(Build.footprintSamples(baseMin, baseMax, 4)) do
		table.insert(contacts, { x = point.X, z = point.Y, bottom = junction })
	end
	return {
		contacts = contacts,
		tilt = false,
		toLowest = true,
		sink = cfg.TREELINE.SINK_STUDS,
		skipMissing = true,
	}
end

-- THROUGH THE TRUCKS' OWN SETTLER AND NOT A SECOND PLACEMENT PATH (lesson L-031): the sampling, the
-- pcall discipline and the measured-not-computed return are written once, and a tree is simply a
-- different PLAN -- no tilt, and settle to the LOWEST contact instead of the highest.
local function seatOnGround(model: Model, cfg, ground: ((number, number) -> number?)?, claw: number): boolean
	if ground == nil then
		return false
	end
	-- `-math.huge` AS THE FLOOR: the truck settler clamps the ground it reads UP to the yard slab,
	-- because a truck in a bay stands on the slab. A tree stands on whatever is actually there.
	-- THE NUMBER THE TREE WAS PLANTED WITH, ON THE TREE. A ring tree's species is a random draw, so
	-- anything checking this afterwards -- a probe, a spec, the next person -- would otherwise have
	-- to guess which fraction applied and would guess wrong for the alders. Measured once already by
	-- guessing: it reported eleven floating trees that were not floating.
	model:SetAttribute("DHClawFraction", claw)
	local settled = settleOnGround(model, cfg, ground, -math.huge, treePlan(model, cfg, claw))
	model:SetAttribute("DHSeated", settled)
	return settled
end

local function treeLine(
	container: Instance,
	anchor: Vector3,
	cfg,
	templates: Instance?,
	groundAt: ((number, number) -> number?)?,
	terrainAt: ((number, number) -> number?)?
)
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
		local yardMidX, yardHalfX, yardMidZ, yardHalfZ = Build.yardRect(anchor, cfg)
		if math.abs(at.X - yardMidX) < yardHalfX + 4 and math.abs(at.Z - yardMidZ) < yardHalfZ + 4 then
			continue
		end
		-- ...NOR ON THE GATHERING YARD (task 191), the third exclusion and the same rule a third
		-- time: a spruce standing among the animals Karen asked to SEE is the same mistake as a
		-- spruce in the road.
		--
		-- IT REMOVES NOTHING TODAY, AND THAT IS MEASURED RATHER THAN HOPED FOR: the western arc
		-- stands its trunks at x ~ -82 to -104 from the anchor (`RADIUS_STUDS` 100 with
		-- `JITTER_STUDS` 9), and the yard's west edge is at -80 -- so the thirty trees FRAME the
		-- gathering instead of standing in it, and `lobby.spec` asserts the count is unchanged. What
		-- this guard is for is the next edit: a wider yard, a shorter radius or more jitter must not
		-- be able to put one back.
		--
		-- THE RECTANGLE IS `Data.gatherPad`'S ROW and is not recomputed here; `+ 4` is the margin the
		-- yard exclusion above already uses, so a trunk on the boundary counts as on the yard.
		local gather = Data.gatherPad(cfg)
		if gather ~= nil then
			local centre = anchor + (gather :: any).OFFSET
			local size = (gather :: any).SIZE
			if math.abs(at.X - centre.X) < size.X / 2 + 4 and math.abs(at.Z - centre.Z) < size.Z / 2 + 4 then
				continue
			end
		end
		-- ...NOR IN FRONT OF THE HOUSE, which is the fourth exclusion and the one Karen was looking at
		-- (2026-10-16: *"what's wrong with those trees next to house"*). The ring is drawn about the
		-- FIELD'S anchor and the lodge stands `LODGE.OFFSET.Z` north of it, so the arc's southern
		-- half runs across the view from the porch -- measured in `E-porch-front.png`, two trunks
		-- standing in the doorway. The Designer's own grove keeps everything north of the house for
		-- this reason (lodge spec 16c: *"the front of a hunting lodge is working ground"*), and the
		-- ring has to keep the same corridor clear.
		local frontX = anchor.X + cfg.LODGE.OFFSET.X
		local frontZ = anchor.Z + cfg.LODGE.OFFSET.Z
		if math.abs(at.X - frontX) < cfg.TREELINE.FRONT_HALF_WIDTH and at.Z < frontZ then
			continue
		end
		-- THROUGH `cloneInstance` AND NOT BY HAND (review round 1, note). The hand-rolled walk here
		-- used `GetDescendants`, which never visits the instance itself, so a `Trees` child that was
		-- a Part rather than a Model came out UNANCHORED AND QUERYABLE -- the one thing this
		-- function's own comment says must not happen.
		-- BIRCH OR ALDER, AND NOTHING ELSE (spec 16b(2)). The allow-list is read by NAME out of the
		-- folder, so a model that is not named -- the empty aspen included -- can never be picked.
		local species = Build.speciesAt(rng:NextNumber(), cfg)
		local template = wood:FindFirstChild(species.MODEL)
		if template == nil then
			stats.fallbacks += 1
			continue
		end
		local scale = if species.TINT == "alder"
			then rng:NextNumber(cfg.ALDER.SCALE[1], cfg.ALDER.SCALE[2])
			else rng:NextNumber(spec.SCALE[1], spec.SCALE[2])
		local planted = cloneInstance(
			template,
			string.format("Tree%02d", index),
			scale,
			Vector3.new(at.X, plantY(at, anchor, cfg, groundAt), at.Z),
			rng:NextNumber(0, math.pi * 2),
			folder,
			true,
			true
		)
		-- NOT THROUGH THE ROOF (part 3c). Measured on the model that actually landed, not on `at`.
		if not clearOfLodge(planted, at, anchor, cfg, groundAt) then
			continue
		end
		-- AND NOT ON ITS ROOTS IN THE AIR (part 3d), which is measured LAST because `clearOfLodge`
		-- may have walked the tree somewhere else entirely.
		if seatOnGround(planted :: Model, cfg, terrainAt or groundAt, species.CLAW_FRACTION or 0) then
			stats.treesSeated += 1
		end
		if species.TINT == "alder" then
			tintAlder(planted, cfg)
		end
	end
	folder.Parent = container
end

-- THE GROVE BY THE HOUSE (spec 16c). Twelve trees in three groups, in the LODGE'S frame, planted
-- on the ground the world reports and sunk the same 0.6 as the ring.
--
-- IT IS A SECOND FUNCTION AND NOT A LONGER `treeLine`, because the two answer different questions:
-- the ring is a procedural ARC at a radius with three exclusions, and this is a hand-placed GROVE
-- from a table the Designer drew. One of them changes when the field changes; the other changes when
-- somebody moves a tree.
local function lodgeTrees(
	container: Instance,
	anchor: Vector3,
	cfg,
	templates: Instance?,
	groundAt: ((number, number) -> number?)?,
	terrainAt: ((number, number) -> number?)?
)
	if templates == nil then
		return
	end
	local wood = (templates :: Instance):FindFirstChild(Data.TEMPLATE.TREES)
	if wood == nil then
		stats.fallbacks += 1
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "LodgeTrees"
	local origin = anchor + cfg.LODGE.OFFSET
	local byKind: { [string]: any } = {}
	for _, row in ipairs(cfg.TREELINE.SPECIES) do
		byKind[row.KIND] = row
	end
	for index, row in ipairs(cfg.LODGE_TREES) do
		local species = byKind[row.kind]
		local template = if species ~= nil then wood:FindFirstChild(species.MODEL) else nil
		if template == nil then
			stats.fallbacks += 1
			continue
		end
		local at = Vector3.new(origin.X + row.x, 0, origin.Z + row.z)
		local planted = cloneInstance(
			template,
			string.format("%s%02d", if row.kind == "alder" then "Alder" else "Birch", index),
			row.scale,
			Vector3.new(at.X, plantY(at, anchor, cfg, groundAt), at.Z),
			math.rad(row.yaw),
			folder,
			true,
			true
		)
		-- NOT THROUGH THE ROOF (part 3c). The grove stands CLOSE to the house on purpose, which is
		-- exactly why it is the half that needs measuring: four of its birches had trunks crossing
		-- the roof slope and one hung through the porch.
		if not clearOfLodge(planted, at, anchor, cfg, groundAt) then
			continue
		end
		if seatOnGround(planted :: Model, cfg, terrainAt or groundAt, species.CLAW_FRACTION or 0) then
			stats.treesSeated += 1
		end
		if species.TINT == "alder" then
			tintAlder(planted, cfg)
		end
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
	stats.treesTinted = 0
	stats.treesMoved = 0
	stats.treesSeated = 0
	stats.treesDropped = 0
	stats.truckWrites = 0
	stats.truckRigs = 0
	-- THE OLD KEEPER WENT WITH THE OLD FOLDER. Dropped here rather than relied on, so a rebuild can
	-- never leave `Build.faceKeeper` turning a body that is no longer in the DataModel.
	keeper = nil
	-- ...AND SO DID THE OLD PADS (task 182), for the same reason: `Build.setPad` must never write a
	-- billboard on a deck that is no longer in the DataModel, which is what `padPart`'s own
	-- `IsDescendantOf` check would otherwise have to catch one scan late.
	table.clear(padParts)
	-- ...AND SO DID THE OLD TRUCKS' RIGS (task 197), for exactly that reason: `Build.setTruck` must
	-- never write a lamp colour or play an engine on a model that is no longer in the DataModel, and
	-- a stale rig would also make `Build.truckRunning` answer about a truck nobody can see.
	table.clear(truckRigs)
	local folder = Instance.new("Folder")
	folder.Name = Data.FOLDER_NAME

	road(folder, anchor, cfg)
	fences(folder, anchor, cfg)
	-- THE WORLD'S OWN GROUND READER REACHES THE TREES TOO (spec 16a). Without it 18 of the 27 ring
	-- trees stood clear of the ground, worst 5.55 -- the identical defect task 186 fixed for the
	-- truck wheels, with the identical fix.
	-- THE SLABS THE ROAD JUST LAID, so a tree is seated on the surface a PLAYER sees and not on the
	-- terrain hidden under it (part 3f). `road` ran four lines up; the parts are there to be asked.
	local walkable: { BasePart } = {}
	local laid = folder:FindFirstChild("Road")
	if laid ~= nil then
		for _, descendant in ipairs(laid:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(walkable, descendant :: BasePart)
			end
		end
	end
	local treeGround = walkableReader(walkable, (seams or {}).terrainAt)
	treeLine(folder, anchor, cfg, templates, (seams or {}).groundAt, treeGround)
	lodgeTrees(folder, anchor, cfg, templates, (seams or {}).groundAt, treeGround)
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
	-- **INVISIBLE SINCE TASK 243** (the Designer's `lobby-yard-spec.md` section 4.3). At 0.6 it was
	-- 12 x 6 studs of slate showing as a grey stain on the grass, right where the player lands --
	-- one of the five things on her *"clean a bit lobby"* list. A `SpawnLocation` has to EXIST, not
	-- to be seen: the porch is the visible arrival place and the lodge is the landmark. Everything
	-- else about it is untouched, and that matters -- `Neutral`, `AllowTeamChangeOnTouch = false`,
	-- `Duration = 0` and `CanQuery = false` are each a rule with its own reason above.
	spawn.Transparency = 1
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
