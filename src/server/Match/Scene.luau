--!strict
-- Match.Scene: the results scene at the end of a drive -- the animals laid out in a row, the four
-- lights on the four corners, and where every player stands to look at them. It is the ONLY writer
-- of `Workspace.DriveScene` and writes nothing else anywhere (CLAUDE.md rule 3).
--
-- Karen, 2026-10-10, verbatim: *"could be that all they standing around the animals there is light
-- on 4 corners and then showing image transperent with results table"*.
--
-- WHAT IT DOES NOT DO, and each one has an owner that does:
--   * it keeps NO score. The results table is the drive's own board, drawn by `src/client/Hud` from
--     the snapshot `Match` already broadcasts -- there is no second score and no new remote.
--   * it does not MOVE A CHARACTER. `Match.Body` is the one writer of where a character stands, and
--     the owner calls `Body.stand` with a CFrame this module computed.
--   * it does not touch a BOAR. `Boar.Body` is the only writer of a boar's Instances, and a drive's
--     carcasses are destroyed by the drive's own `clearBoars` the moment it ends -- so what is laid
--     out here is a DISPLAY COPY per recorded kill (see "why a display copy" below).
--   * it does not touch `Lighting`. Karen asked for light on four corners, which is four lamps in
--     the world; the time of day is Studio-edited content with no run-time writer in this repo.
--
-- WHY A DISPLAY COPY AND NOT THE CARCASS ITSELF. Three facts, each already in the repo:
--   1. `Boar.Body` owns a boar's Instances, and a second writer of them is the failure
--      docs/PROJECT_CONTEXT.md names ("two systems wrote the creature's position").
--   2. the drive ENDS by clearing its animals: `Phase.enterScoring` emits `clearBoars`, which is
--      `Runtime:clear("driveOver")` and despawns every carcass. The bodies are gone exactly when
--      the scene wants them.
--   3. in the Forest Test the drive does not own the animals at all -- `ForestTest.readOnlyBoars`
--      hands `Match` a view with no `spawn` and no `clear`, so moving one would be the drive writing
--      another owner's world.
-- So the scene is built from `Match`'s own record of what was shot this drive (kind by kind), and
-- each animal is one anchored, non-colliding, `CanQuery = false` box of that kind's size. It is a
-- GREY BOX on purpose, like every other first cut in this repo: Karen judges the look and the next
-- step is one injected template function, not a rewrite (TASKS.md row 159a).
--
-- Pattern: the intermission of an arena shooter -- every client is moved to one point and frozen
-- while the scoreboard is up (ioquake3 `BeginIntermission` / `MoveClientToIntermission`,
-- code/game/g_main.c, GPL-2.0). The repo's own borrow is task 158's hold: the same
-- `Body.holdCharacter` freeze, applied to the whole roster instead of one team.
--   PointLight https://create.roblox.com/docs/reference/engine/classes/PointLight
--     Color, Brightness and Range are the three numbers a lamp has; the page documents no falloff
--     curve, so what the four of them look like together is a screenshot and not an estimate.
--
-- Design: docs/design/drive.md (section 4.3 is the placement seam this reuses)
-- Note:   docs/research/2026-10-12-drive-end-and-results-scene.md
local Workspace = game:GetService("Workspace")

local Scene = {}

-- The one run-time container this module creates, and it holds the lamps and the display animals and
-- nothing else, ever. Workspace is not Rojo-owned and the harness compares the EDIT-mode DataModel,
-- so a run-time folder cannot dirty a run -- exactly as `Workspace.DriveMarkers` and
-- `Workspace.WeaponEffects` do not (`src/server/Match/Body.luau` header).
Scene.FOLDER_NAME = "DriveScene"
Scene.LIGHT_PREFIX = "Light"
Scene.ANIMAL_PREFIX = "Animal"

local built = 0
local cleared = 0
local lights = 0
local animals = 0

function Scene.stats()
	return { built = built, cleared = cleared, lights = lights, animals = animals }
end

function Scene.folder(): Folder?
	local existing = Workspace:FindFirstChild(Scene.FOLDER_NAME)
	return if existing and existing:IsA("Folder") then existing :: Folder else nil
end

-- DESTROYED AND REBUILT, never added to (the `Body.OUTFIT_NAME` discipline): the folder holds exactly
-- one drive's scene at all times and never two drives' worth of lamps.
function Scene.clear(): boolean
	local folder = Scene.folder()
	if not folder then
		return false
	end
	folder:Destroy()
	cleared += 1
	return true
end

-- ------------------------------------------------------------------------------- the pure layout
--
-- Every function below is PURE and exported: no Instance, no service, no clock. That is what lets
-- tests/server/match_scene.spec.luau assert who stands where, how many lamps there are and how the
-- row is spaced, with no drive, no world and no players (the shape `Body.placementFor` and
-- `Match.quickSpawnFor` already have).

-- The row's own sideways axis: across the direction the scene faces, flat. `facing` is the drive
-- line's normal, which points up the drive at the beaters, so the row lies ACROSS the push and
-- everybody standing round it looks at the animals side-on rather than end-on.
function Scene.sideAxis(facing: Vector3): Vector3
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-4 then
		return Vector3.xAxis
	end
	return flat.Unit:Cross(Vector3.yAxis).Unit
end

-- HOW BIG A DISPLAY ANIMAL IS: the scene's own box, scaled by the kind's own scale, so a sow and a
-- cub are not the same size as a boar. `Boar.CONFIG.KINDS` is not required here -- the scales are
-- handed in as data on the config, because this module must not learn what a boar is.
function Scene.animalSize(kind: string?, cfg): Vector3
	local scene = cfg.SCENE
	local scale = (scene.ANIMAL_SCALES or {})[kind or ""] or 1
	return scene.ANIMAL_SIZE * scale
end

-- THE ROW. `count` animals laid side by side on the ground at `spot`, centred on it, `SPACING_STUDS`
-- apart, every one of them lying the same way round -- which is how a day's bag is actually laid out.
-- Index 1 is the first animal shot (the owner keeps the kills in order), so the row reads left to
-- right as the drive happened.
function Scene.rowLayout(spot: Vector3, facing: Vector3, count: number, cfg): { CFrame }
	local out = {}
	if count <= 0 then
		return out
	end
	local scene = cfg.SCENE
	local side = Scene.sideAxis(facing)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude < 1e-4 then Vector3.zAxis else flat.Unit
	local middle = (count + 1) / 2
	for index = 1, count do
		local at = spot + side * ((index - middle) * scene.SPACING_STUDS)
		out[index] = CFrame.lookAt(at, at + look)
	end
	return out
end

-- WHERE THE PEOPLE STAND: a ring round the animals, every one of them facing the middle. Evenly
-- spaced from the side axis, deterministic in index order, so "who is moved where" is a fact a spec
-- can state rather than a thing that happens.
--
-- `STAND_HEIGHT_STUDS` is the drive's own number for how far above the ground a character is put
-- down, so a player at the scene is as high off the floor as a hunter on a stand.
function Scene.ringLayout(spot: Vector3, count: number, cfg): { CFrame }
	local out = {}
	if count <= 0 then
		return out
	end
	local scene = cfg.SCENE
	local centre = spot + Vector3.new(0, cfg.STAND_HEIGHT_STUDS, 0)
	for index = 1, count do
		local angle = (index - 1) * (2 * math.pi / count)
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * scene.RING_RADIUS_STUDS
		local at = centre + offset
		out[index] = CFrame.lookAt(at, centre)
	end
	return out
end

-- THE FOUR CORNERS, and the number is Karen's: *"there is light on 4 corners"*. A square round the
-- row, at `CORNER_STUDS` on both axes, returned in a fixed order so the lamp named `Light1` is the
-- same corner every drive.
function Scene.cornerPositions(spot: Vector3, facing: Vector3, cfg): { Vector3 }
	local scene = cfg.SCENE
	local side = Scene.sideAxis(facing)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude < 1e-4 then Vector3.zAxis else flat.Unit
	local reach = scene.CORNER_STUDS
	return {
		spot + side * reach + look * reach,
		spot - side * reach + look * reach,
		spot - side * reach - look * reach,
		spot + side * reach - look * reach,
	}
end

-- ------------------------------------------------------------------------------- the Instances

local function newPart(name: string, size: Vector3, cframe: CFrame, colour: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	-- `CanQuery = false` IS LOAD-BEARING, and it is the same reason the outfit's plates and the
	-- forest's markers set it: a prop that stops a pellet changes what the shot hit, and what the
	-- shot hit is what the safety rule and the hit record read.
	part.CanQuery = false
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- BUILDS THE WHOLE SCENE, and takes the one before it down first. `kills` is the drive's own record,
-- in the order the animals were shot: `{ { kind = "male" }, ... }`. Returns how many animals were
-- laid out, which is `#kills` capped at `MAX_ANIMALS` -- a cap, because a long drive's row must not
-- run off into the wood.
function Scene.build(spot: Vector3, facing: Vector3, kills: { any }, cfg): number
	Scene.clear()
	local scene = cfg.SCENE
	local folder = Instance.new("Folder")
	folder.Name = Scene.FOLDER_NAME
	folder.Parent = Workspace

	local count = math.min(#kills, scene.MAX_ANIMALS)
	local row = Scene.rowLayout(spot, facing, count, cfg)
	for index = 1, count do
		local kill = kills[index]
		local kind = if type(kill) == "table" then kill.kind else nil
		local size = Scene.animalSize(kind, cfg)
		local at = row[index] * CFrame.new(0, size.Y / 2, 0)
		local part = newPart(string.format("%s%d", Scene.ANIMAL_PREFIX, index), size, at, scene.ANIMAL_COLOR, folder)
		-- WHAT IT WAS, on the part itself: a console line, a Studio Explorer and a spec all read the
		-- same fact, and the next step (a real model per kind) has the kind already here.
		part:SetAttribute("Kind", kind or "unknown")
		animals += 1
	end

	for index, corner in ipairs(Scene.cornerPositions(spot, facing, cfg)) do
		local post = newPart(
			string.format("%s%d", Scene.LIGHT_PREFIX, index),
			scene.POST_SIZE,
			CFrame.new(corner + Vector3.new(0, scene.POST_SIZE.Y / 2, 0)),
			scene.POST_COLOR,
			folder
		)
		local light = Instance.new("PointLight")
		light.Name = "Lamp"
		light.Color = scene.LIGHT_COLOR
		light.Brightness = scene.LIGHT_BRIGHTNESS
		light.Range = scene.LIGHT_RANGE_STUDS
		-- SHADOWS OFF: four shadow-casting lights over a row of bodies is four shadow maps for a
		-- 25-second scene, and this is the one number in here that is about cost rather than look.
		light.Shadows = false
		light.Parent = post
		lights += 1
	end

	built += 1
	return count
end

return Scene
