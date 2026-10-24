--!strict
-- Match.Scene: the results scene at the end of a drive -- the animals laid out in ROWS, the four
-- TORCHES on the four corners, and where every player stands to look at them. It is the ONLY writer
-- of `Workspace.DriveScene` and writes nothing else anywhere (CLAUDE.md rule 3).
--
-- Karen, 2026-10-10, verbatim: *"could be that all they standing around the animals there is light
-- on 4 corners and then showing image transperent with results table"*.
--
-- ...AND TASK 168 IS HER SECOND LOOK AT IT, 2026-10-12 ~21:45, verbatim: *"and on the end we need to
-- gather all animals in one place everyone around and torches 4 in corners / animals layed down in
-- front in several lines if more"*. Three changes, and each one is a number and a loop here:
--   1. SEVERAL ROWS. One row of twelve at `SPACING_STUDS` 6 is 66 studs wide, which is a hedge and
--      not a bag: `PER_ROW` animals to a row and then a new row `ROW_SPACING_STUDS` behind it, the
--      whole block centred on the spot (`Scene.rowLayout`, still the one layout function).
--   2. THE RING AND THE CORNERS NOW CONTAIN THE BLOCK. They were two fixed radii, so with more than
--      four animals the people stood INSIDE the row and the lamps stood among the bodies -- measured
--      as arithmetic, not guessed: `RING_RADIUS_STUDS` 14 against a 33-stud half-width.
--      `Scene.layoutExtent` is the one measurement of how big the block is and both read it.
--   3. A TORCH IS A FIRE, NOT A LAMP. `Fire` is an engine particle that animates itself, which is
--      what buys Karen's *"warm flicker"* with no per-frame writer anywhere -- see `Scene.build`.
--
-- ...AND TASK 255 IS HER THIRD, 2026-10-24, verbatim: *"also when there is a lot animals killed on
-- end of game we need gather them in several rows"*. Task 168 built the rows and they worked; what
-- failed is that A RED DEER ARRIVED. Three changes, all of them in `Match.CONFIG.SCENE` except one:
--   4. THE SPACING IS NOW BIG ENOUGH FOR THE BIGGEST ANIMAL, MEASURED. A display lies on its SIDE,
--      so what it takes across the row is the standing mesh's HEIGHT -- and a rolled stag is
--      7.9202 studs across where the old `SPACING_STUDS` 6 gave it 6. **Two stags overlapped by
--      1.9202 studs**, which is a pile and not a bag. 9 leaves 1.0798 studs of grass. The four
--      measured meshes are in that config's own comment.
--   5. THE CAP IS 16 AND NOT 12, because her sentence starts *"when there is a lot animals killed"*
--      and at 12 a long drive's bag was truncated. It is 16 and NOT the Director's 20+ because the
--      lobby's gathering yard will not hold 20 -- MEASURED, and `Match.CONFIG.SCENE.MAX_ANIMALS`
--      carries the arithmetic: a 56-stud pad and a chimney 29.0 studs from the gathering's centre
--      allow a reach of 28, which at the new spacing is a 4 x 4 block and not a 5 x 4 one. Twenty
--      animals need the yard MOVED, which is a lobby decision; it is in `ESCALATE.md`.
--      `PER_ROW` came down from 6 to 4 for the same reason, and the block is now SQUARE (27 x 27).
--   6. THE BAG IS LAID OUT BY SPECIES AND THEN BY SIZE (`Scene.ordered`), and not in the order they
--      were shot. The ORDER is data (`SCENE.KIND_ORDER`), so this file still does not know what a
--      boar is or which animal is bigger.
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
-- each animal is one anchored, non-colliding, `CanQuery = false` display of that kind.
--
-- ...AND SINCE TASK 173 THE DISPLAY IS THE REAL ANIMAL. Karen, 2026-10-13 ~09:30, verbatim: *"and
-- after hunt over we need to see boars shooted not boxes when we stand around"*. It is the one
-- injected template function TASKS.md row 159a(a) said it would be, and nothing else about the scene
-- moved: `displayFor(kind, groundCFrame)` is handed to `Scene.build` by the owner, answers a finished
-- model lying dead on its side, and answers nil when there is no asset -- in which case this module
-- builds the same grey box it always did, for that animal. The torches, the ring, the rows, the
-- spacing and the cap of twelve are untouched.
--   * WHAT STAYS HERE: the folder, and the LAYOUT -- where each animal is and which way it faces.
--   * WHAT DOES NOT: what a boar looks like and how a dead one lies. `Boar.Body.displayCarcass`
--     builds it, from the same template a live boar of that kind is dressed from, and this module
--     never writes a CFrame on a display (it hands the ground frame in and parents what comes back).
--   * WHICH SIDE IT LIES ON is the tradition's answer and is the asset owner's number, not one of
--     this module's: see `Boar.CONFIG.MODEL.DISPLAY_ROLL_DEG`.
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
--         docs/research/2026-10-13-real-animals-at-the-gathering.md (task 173: the real animals)
local Workspace = game:GetService("Workspace")

local Scene = {}

-- The one run-time container this module creates, and it holds the lamps and the display animals and
-- nothing else, ever. Workspace is not Rojo-owned and the harness compares the EDIT-mode DataModel,
-- so a run-time folder cannot dirty a run -- exactly as `Workspace.DriveMarkers` and
-- `Workspace.WeaponEffects` do not (`src/server/Match/Body.luau` header).
Scene.FOLDER_NAME = "DriveScene"
Scene.LIGHT_PREFIX = "Light"
Scene.ANIMAL_PREFIX = "Animal"
-- The one child of a torch post that is not the post: the burning end, which carries the `Fire` and
-- the `PointLight` (task 168). Named here so a spec and a live probe look for one string.
Scene.FLAME_NAME = "Flame"

-- WHAT THE OWNER HANDS IN FOR THE REAL ANIMALS (task 173): a kind, the ground frame this module laid
-- the animal on, and a finished model back -- or nil, which means "keep the grey box". Named here so
-- the one seam this module has is one line long and is read before `Scene.build`.
export type DisplayFor = (string?, CFrame) -> Instance?

local built = 0
local cleared = 0
local lights = 0
local animals = 0
local rowsBuilt = 0
-- HOW MANY OF THIS SCENE'S ANIMALS WERE THE REAL MODEL AND HOW MANY FELL BACK TO THE BOX (task 173).
-- Two counters rather than one, because "3 animals" cannot tell a drive whose assets never loaded
-- from one whose assets are fine -- and that is the first question to ask of a screenshot of grey
-- boxes.
--
-- PER BUILD, NOT PER SESSION, and that is round 1's finding 1: they are `rowsBuilt`'s neighbours and
-- they are reset where it is assigned, because the owner prints all three in ONE sentence beside the
-- per-drive `laid` ("gathered 2 animal(s) in 1 row(s): 4 real model(s)" is not a sentence about
-- anything). It also restores the breakdown's whole purpose -- `models = 0` means the asset never
-- arrived -- which a session total makes unreachable after the first model of the session.
-- `built` and `cleared` stay session counters: they are not part of that sentence.
local models = 0
local boxes = 0

function Scene.stats()
	return {
		built = built,
		cleared = cleared,
		lights = lights,
		animals = animals,
		rows = rowsBuilt,
		models = models,
		boxes = boxes,
	}
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

-- HOW MANY TO A ROW, never less than one. A `PER_ROW` of 0 in a world's config would divide the
-- layout by zero and lay every animal on top of its neighbour, so the floor is here and not at three
-- call sites.
--
-- ...AND THE MISSING-VALUE CASE IS 1 AND NOT `math.huge` (round 1's note, which was right): a nil
-- `PER_ROW` made this `inf`, so `rowCount` was `ceil(count/inf)` = 0 and `rowLayout`'s `inRow -
-- middle` was `inf - inf` -- a row of NaN positions. Unreachable today, because every `SCENE` table
-- in the repo sets `PER_ROW`; what was wrong was the CLAIM above it, and now both are true.
function Scene.perRow(cfg): number
	return math.max(1, math.floor((cfg.SCENE.PER_ROW or 1) :: number))
end

-- HOW MANY ROWS `count` ANIMALS MAKE. PURE, and the one answer: the row layout, the extent and the
-- spec all read it, so "how deep is the block" cannot be worked out twice differently.
function Scene.rowCount(count: number, cfg): number
	if count <= 0 then
		return 0
	end
	return math.ceil(count / Scene.perRow(cfg))
end

-- HOW BIG THE WHOLE BLOCK IS, from the spot's own centre: half its width across the rows and half
-- its depth along them, in studs. PURE and exported, because it is what makes the ring and the
-- corners CONTAIN the animals instead of standing among them (task 168) -- one measurement, two
-- readers.
--
-- THE WIDTH IS MEASURED OFF THE FULLEST ROW, which is the first one whenever there is more than one:
-- `PER_ROW` animals `SPACING_STUDS` apart span `(PER_ROW - 1) * SPACING`, so the half-width is half
-- of that. Zero animals is a block of nothing, and 0, 0 is the honest answer to that.
function Scene.layoutExtent(count: number, cfg): (number, number)
	if count <= 0 then
		return 0, 0
	end
	local scene = cfg.SCENE
	local rows = Scene.rowCount(count, cfg)
	local widest = math.min(count, Scene.perRow(cfg))
	local halfWidth = (widest - 1) * scene.SPACING_STUDS / 2
	local halfDepth = (rows - 1) * (scene.ROW_SPACING_STUDS or scene.SPACING_STUDS) / 2
	return halfWidth, halfDepth
end

-- WHAT ORDER THE BAG IS LAID OUT IN (task 255). KAREN, 2026-10-24: *"also when there is a lot
-- animals killed on end of game we need gather them in several rows"*; the Director: *"Lay them in
-- several tidy rows (by species, then size)"*.
--
-- PURE, AND IT RETURNS A NEW LIST: the drive's own `kills` record is the order they were SHOT and
-- `Match` keeps reading it for the score and the report, so nothing here may reorder it in place.
--
-- THE RANK COMES FROM `SCENE.KIND_ORDER`, which is DATA -- the boar kinds biggest first, then the
-- red deer's biggest first -- so this function never learns what a boar is or which animal is
-- bigger. That is the same rule the grey box's `ANIMAL_SCALES` is here for.
--
-- IT IS A STABLE SORT AND `table.sort` IS NOT ONE (the engine's own docs say the order of equal
-- elements is undefined). Two stags would otherwise swap places between two builds of the same bag,
-- which is a scene that is different every time it is rebuilt for no reason anybody can see. The
-- shot index is the tie-break, so inside one kind the bag still reads in the order she shot them.
--
-- A KIND THAT IS NOT IN THE LIST SORTS LAST, in shot order: a species added later is laid out
-- honestly -- at the back, together -- rather than scattered through the rows, and nobody has to
-- remember this line for that to be true.
function Scene.ordered(kills: { any }, cfg): { any }
	local order = cfg.SCENE.KIND_ORDER
	local rank: { [string]: number } = {}
	if type(order) == "table" then
		for index, kind in ipairs(order) do
			rank[kind] = index
		end
	end
	local last = (if type(order) == "table" then #order else 0) + 1
	local rows = {}
	for index, kill in ipairs(kills) do
		local kind = if type(kill) == "table" then tostring(kill.kind) else ""
		table.insert(rows, { kill = kill, rank = rank[kind] or last, index = index })
	end
	table.sort(rows, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end)
	local out = {}
	for index, row in ipairs(rows) do
		out[index] = row.kill
	end
	return out
end

-- THE ROWS. `count` animals laid side by side on the ground at `spot`, `SPACING_STUDS` apart, every
-- one of them lying the same way round -- which is how a day's bag is actually laid out.
--
-- IT KNOWS NOTHING ABOUT WHICH ANIMAL IS WHICH: index 1 goes at the front-left and index `count` at
-- the back-right, and WHAT INDEX 1 IS is the caller's. **Since task 255 it is the highest-ranked
-- SPECIES and no longer the first animal shot** -- `Scene.build` sorts the capped bag through
-- `Scene.ordered` before it gets here, and this header used to say the opposite (round 1, note).
--
-- SEVERAL ROWS SINCE TASK 168 (Karen: *"animals layed down in front in several lines if more"*):
-- `PER_ROW` to a row, the next row `ROW_SPACING_STUDS` further BACK -- away from the drive, behind
-- the first -- and the whole block centred on the spot in both axes. So the front row is the one
-- nearest the people, and since task 255 it is the biggest animals of the first species in
-- `SCENE.KIND_ORDER`.
--
-- A SHORT LAST ROW IS CENTRED ON ITS OWN WIDTH and not on the full one, which is what makes a bag of
-- seven read as 6 + 1 in the middle rather than as 6 + 1 hanging off the left end.
function Scene.rowLayout(spot: Vector3, facing: Vector3, count: number, cfg): { CFrame }
	local out = {}
	if count <= 0 then
		return out
	end
	local scene = cfg.SCENE
	local side = Scene.sideAxis(facing)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude < 1e-4 then Vector3.zAxis else flat.Unit
	local perRow = Scene.perRow(cfg)
	local rows = Scene.rowCount(count, cfg)
	local depth = scene.ROW_SPACING_STUDS or scene.SPACING_STUDS
	local middleRow = (rows + 1) / 2
	for index = 1, count do
		local row = math.ceil(index / perRow)
		local inRow = index - (row - 1) * perRow -- 1..perRow within this row
		local thisRow = math.min(perRow, count - (row - 1) * perRow)
		local middle = (thisRow + 1) / 2
		local at = spot + side * ((inRow - middle) * scene.SPACING_STUDS) - look * ((row - middleRow) * depth)
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
-- HOW FAR OUT THE PEOPLE STAND, and since task 168 it is the BLOCK's size and not one number:
-- `RING_RADIUS_STUDS` as before, or far enough to clear the animals plus `RING_MARGIN_STUDS`,
-- whichever is bigger. PURE and exported so the spec can state the containment as arithmetic.
--
-- THE BLOCK'S CORNER IS WHAT MUST BE CLEARED, not its half-width: the ring is a circle and the block
-- is a rectangle, so the distance to beat is the diagonal `sqrt(w^2 + d^2)`. With the shipped
-- numbers since task 255 -- 16 animals at `PER_ROW` 4, spacing 9 and row spacing 9 -- that is
-- sqrt(13.5^2 + 13.5^2) = 19.1, plus the margin: a ring of 25.1 and lamps at 27.1, which is what
-- has to stand inside the lobby's 56-stud gathering yard (`lobby.spec` asserts exactly that).
function Scene.ringRadiusFor(animalCount: number?, cfg): number
	local scene = cfg.SCENE
	local halfWidth, halfDepth = Scene.layoutExtent(animalCount or 0, cfg)
	local corner = math.sqrt(halfWidth * halfWidth + halfDepth * halfDepth)
	return math.max(scene.RING_RADIUS_STUDS, corner + (scene.RING_MARGIN_STUDS or 0))
end

function Scene.ringLayout(spot: Vector3, count: number, cfg, animalCount: number?): { CFrame }
	local out = {}
	if count <= 0 then
		return out
	end
	local centre = spot + Vector3.new(0, cfg.STAND_HEIGHT_STUDS, 0)
	local radius = Scene.ringRadiusFor(animalCount, cfg)
	for index = 1, count do
		local angle = (index - 1) * (2 * math.pi / count)
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * radius
		local at = centre + offset
		out[index] = CFrame.lookAt(at, centre)
	end
	return out
end

-- THE FOUR CORNERS, and the number is Karen's: *"there is light on 4 corners"*. A square round the
-- row, at `CORNER_STUDS` on both axes, returned in a fixed order so the lamp named `Light1` is the
-- same corner every drive.
-- ...AND THE SQUARE HOLDS THE PEOPLE AS WELL AS THE ANIMALS (task 168). It was one fixed number, so
-- a bag of twelve put all four torches INSIDE the row of bodies.
--
-- `CORNER_STUDS` IS NOW A FLOOR AND NOT THE ANSWER, which is what keeps the scene Karen has already
-- looked at byte for byte: with the shipped numbers a small bag's ring is `RING_RADIUS_STUDS` 14,
-- plus `CORNER_MARGIN_STUDS` 2 is 16, which IS `CORNER_STUDS` -- so nothing moves until the ring
-- itself has to grow. The margin is what *"just outside the ring"* meant all along, written down.
function Scene.cornerReachFor(animalCount: number?, cfg): number
	local scene = cfg.SCENE
	local ring = Scene.ringRadiusFor(animalCount, cfg)
	return math.max(scene.CORNER_STUDS, ring + (scene.CORNER_MARGIN_STUDS or 0))
end

function Scene.cornerPositions(spot: Vector3, facing: Vector3, cfg, animalCount: number?): { Vector3 }
	local side = Scene.sideAxis(facing)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local look = if flat.Magnitude < 1e-4 then Vector3.zAxis else flat.Unit
	local reach = Scene.cornerReachFor(animalCount, cfg)
	return {
		spot + side * reach + look * reach,
		spot - side * reach + look * reach,
		spot - side * reach - look * reach,
		spot + side * reach - look * reach,
	}
end

-- ------------------------------------------------------------------------------- the Instances

-- ON THE GROUND UNDER THE POINT, AND NOT ON THE SPOT'S OWN Y (task 192). The layout above is flat
-- arithmetic -- one `spot` and offsets round it -- and on the `edge` layout's 80-stud hillside that
-- buries the far half of a row and floats the near half. So every point this module puts an Instance
-- at asks the reader it was handed where the ground under THAT point is.
--
-- IT IS NOT A SECOND DEFINITION OF "WHERE IS THE GROUND": the function is the world's own single
-- reader, handed down by the owner (`Match.applyScene` passes `Body.groundUnder`), and this module
-- only substitutes the Y. `nil` reader, or a reader that answers nil for this point, leaves the
-- point exactly as the layout computed it -- which is the scene this repo built before this task.
-- Note: docs/research/2026-10-15-one-placement-rule.md
local function onGround(cframe: CFrame, groundAt: ((number, number, number?) -> number?)?): CFrame
	if groundAt == nil then
		return cframe
	end
	local at = cframe.Position
	-- ASKED FROM THE POINT'S OWN HEIGHT (Reviewer round 2, note 1). Without the third argument this
	-- got the reader's COLUMN answer -- the cast from the sky -- so a carcass or a torch laid out
	-- under one of this place's `Session` canopies was hung at canopy height, which is the one
	-- Instance Karen looks at that finding 1 still reached.
	local ok, y = pcall(groundAt :: any, at.X, at.Z, at.Y)
	if not ok or type(y) ~= "number" then
		return cframe
	end
	return cframe - at + Vector3.new(at.X, y :: number, at.Z)
end

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
--
-- **IT IS NOT LAID OUT IN THAT ORDER SINCE TASK 255** (round 1, note): the first `MAX_ANIMALS` of
-- `kills` are taken, and THEN sorted by species and size through `Scene.ordered`. So the record this
-- is handed stays the shot order for everybody else who reads it, and what reaches the ground is a
-- tidy bag. Which animals are dropped is still decided by WHEN they were shot and never by what they
-- were.
--
-- `displayFor` IS THE REAL ANIMAL, AND IT IS THE SEAM TASK 159a(a) NAMED (task 173). Karen,
-- 2026-10-13: *"and after hunt over we need to see boars shooted not boxes when we stand around"*.
-- It is `function(kind: string?, ground: CFrame) -> Instance?`, handed in by the owner -- the shape
-- `Boar.setModelSource`, `Bots.setRigSource` and `world.placement` already have -- and it answers a
-- FINISHED, UNPARENTED model lying dead on its side at the CFrame this module laid out.
--
-- SO THIS MODULE STILL DOES NOT KNOW WHAT A BOAR IS. It owns the folder and the LAYOUT -- where each
-- animal is and which way it faces -- and the asset's owner owns the animal and its pose
-- (`Boar.Body.displayCarcass`). Nothing here writes a CFrame on a display: the ground frame goes in,
-- the model comes back, and it is parented as it is.
--
-- NIL IS THE FALLBACK, PER ANIMAL. No `displayFor` at all (a pure spec, the DEV quick test), no
-- template yet, the asset unpublished, `BOAR_MODEL` off, or a template that is not one mesh: that
-- animal is the grey box of task 159, in the same place and at the same size. A mixed row is an
-- honest row.
--
-- `groundAt` IS WHERE THE GROUND IS (task 192), optional and the world's own reader. Without it this
-- lays everything on the spot's own Y, which is what it did before -- and which put half a row
-- inside a hill on a sloped layout.
function Scene.build(
	spot: Vector3,
	facing: Vector3,
	kills: { any },
	cfg,
	displayFor: DisplayFor?,
	groundAt: ((number, number, number?) -> number?)?
): number
	Scene.clear()
	local scene = cfg.SCENE
	local folder = Instance.new("Folder")
	folder.Name = Scene.FOLDER_NAME
	folder.Parent = Workspace

	local count = math.min(#kills, scene.MAX_ANIMALS)
	-- THE CAP IS TAKEN FIRST AND THE TIDYING SECOND (task 255), and that order is a decision: capped
	-- first, the bag she sees is *the first `MAX_ANIMALS` she shot*, laid out tidily. Sorted first,
	-- the cap would silently drop the smallest animals of the last species in the list -- so a drive
	-- of four calves and sixteen males would lay out sixteen MALES, four of them shot after the cap,
	-- and her four calves would be gone with nothing on screen saying so.
	--
	-- SO THE SLICE IS TAKEN HERE, ON THE SHOT ORDER, AND `Scene.ordered` NEVER SEES THE REST
	-- (round 1, finding 1 -- the Reviewer was right and this is what the comment above always said
	-- the code did). `table.move` into a fresh list rather than `table.clone`, because the drive's
	-- own `kills` record is longer than the cap and `Match` keeps reading it for the score and the
	-- report.
	local capped = table.move(kills, 1, count, 1, {})
	local laidOut = Scene.ordered(capped, cfg)
	local row = Scene.rowLayout(spot, facing, count, cfg)
	-- The rows the block was laid out in, for the console line the owner prints: "how many rows" is
	-- the one thing about this scene that a report cannot work out from the animal count alone
	-- without re-deriving `PER_ROW`.
	rowsBuilt = Scene.rowCount(count, cfg)
	-- ...AND THE BREAKDOWN IS THIS SCENE'S (round 1, finding 1): assigned here, with `rowsBuilt`, so
	-- `models + boxes == laid` for the scene that was just built and the owner's one-sentence line
	-- adds up. A drive that lays nothing out reports 0 and 0, which is also true.
	models = 0
	boxes = 0
	for index = 1, count do
		local kill = laidOut[index]
		local kind = if type(kill) == "table" then kill.kind else nil
		local name = string.format("%s%d", Scene.ANIMAL_PREFIX, index)
		-- THE REAL ANIMAL FIRST, THE BOX IF THERE IS NONE (task 173). One ask per animal, with the
		-- ground frame the row put it on: `row[index]` is on the ground facing the drive, which is
		-- exactly what a thing lying on the ground needs to be told.
		local on = onGround(row[index], groundAt)
		local display = if displayFor then displayFor(kind, on) else nil
		local laid: Instance
		if display ~= nil then
			display.Name = name
			display.Parent = folder
			laid = display
			models += 1
		else
			local size = Scene.animalSize(kind, cfg)
			local at = on * CFrame.new(0, size.Y / 2, 0)
			laid = newPart(name, size, at, scene.ANIMAL_COLOR, folder)
			boxes += 1
		end
		-- WHAT IT WAS, on the thing itself: a console line, a Studio Explorer and a spec all read the
		-- same fact, and it is written the same way whether this animal is a model or a box.
		laid:SetAttribute("Kind", kind or "unknown")
		-- ...AND WHETHER IT IS THE REAL ANIMAL. One attribute is the difference between "the asset
		-- did not load" and "the scene is wrong", and a live probe can count it without knowing what
		-- a boar model looks like.
		laid:SetAttribute("Model", display ~= nil)
		animals += 1
	end
	-- THE FOUR TORCHES (task 168). Karen: *"torches 4 in corners"* -- *"real torches: a post with a
	-- FIRE"*. One post, one `Flame` part at the top of it, and on the flame the two things that make
	-- a fire: a `Fire` and the `PointLight` that was the whole lamp before this task.
	--
	-- `Fire` IS WHY THERE IS NO FLICKER LOOP ANYWHERE. It is an engine particle emitter whose flame
	-- animates itself -- the two numbers it has are `Size` and `Heat`, and nothing has to be written
	-- per frame to make it move. A flickering `PointLight.Brightness` would need a second writer of
	-- this folder running at render rate for a 25-second scene, which is a per-frame cost and a
	-- second owner for an effect the particle already gives.
	--   Fire       https://create.roblox.com/docs/reference/engine/classes/Fire
	--   PointLight https://create.roblox.com/docs/reference/engine/classes/PointLight
	--
	-- THE LIGHT HANGS ON THE FLAME AND NOT ON THE POST, which is a change of one stud-and-a-half of
	-- meaning: a `PointLight` emits from its parent part's own position, so on a 10-stud post it was
	-- lighting the bodies from knee height at the post's middle. It now shines from the fire.
	for index, flat in ipairs(Scene.cornerPositions(spot, facing, cfg, count)) do
		-- EACH TORCH ON ITS OWN GROUND (task 192): the four corners are up to `cornerReachFor` studs
		-- from the spot in both axes, so on a slope a flat Y stands one of them in the air and sinks
		-- the one opposite it.
		local corner = onGround(CFrame.new(flat), groundAt).Position
		local post = newPart(
			string.format("%s%d", Scene.LIGHT_PREFIX, index),
			scene.POST_SIZE,
			CFrame.new(corner + Vector3.new(0, scene.POST_SIZE.Y / 2, 0)),
			scene.POST_COLOR,
			folder
		)
		local flame = newPart(
			Scene.FLAME_NAME,
			scene.FLAME_SIZE,
			CFrame.new(corner + Vector3.new(0, scene.POST_SIZE.Y, 0)),
			scene.FLAME_COLOR,
			post
		)
		flame.Material = Enum.Material.Neon
		local fire = Instance.new("Fire")
		fire.Name = "Flames"
		fire.Color = scene.FIRE_COLOR
		fire.SecondaryColor = scene.FIRE_SECONDARY_COLOR
		fire.Size = scene.FIRE_SIZE
		fire.Heat = scene.FIRE_HEAT
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Name = "Lamp"
		light.Color = scene.LIGHT_COLOR
		light.Brightness = scene.LIGHT_BRIGHTNESS
		light.Range = scene.LIGHT_RANGE_STUDS
		-- SHADOWS OFF: four shadow-casting lights over a row of bodies is four shadow maps for a
		-- 25-second scene, and this is the one number in here that is about cost rather than look.
		light.Shadows = false
		light.Parent = flame
		lights += 1
	end

	built += 1
	return count
end

return Scene
